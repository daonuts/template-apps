/*
 * SPDX-License-Identitifer:    GPL-3.0-or-later
 *
 * This file requires contract dependencies which are licensed as
 * GPL-3.0-or-later, forcing it to also be licensed as such.
 *
 * This is the only file in your project that requires this license and
 * you are free to choose a different license for the rest of the project.
 */

pragma solidity ^0.4.24;

import "@aragon/os/contracts/factory/DAOFactory.sol";
import "@aragon/os/contracts/apm/Repo.sol";
import "@aragon/os/contracts/lib/ens/ENS.sol";
import "@aragon/os/contracts/lib/ens/PublicResolver.sol";
import "@aragon/os/contracts/apm/APMNamehash.sol";

import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-voting/contracts/Voting.sol";
import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";

import "@1hive/airdrop-app/contracts/Airdrop.sol";

import "./TokenCache.sol";


contract TemplateBase is APMNamehash, TokenCache {
    ENS public ens;
    DAOFactory public fac;

    event DeployDao(address dao);
    event InstalledApp(address appProxy, bytes32 appId);

    constructor(DAOFactory _fac, ENS _ens) public {
        ens = _ens;

        // If no factory is passed, get it from on-chain bare-kit
        if (address(_fac) == address(0)) {
            bytes32 bareKit = apmNamehash("bare-kit");
            fac = TemplateBase(latestVersionAppBase(bareKit)).fac();
        } else {
            fac = _fac;
        }
    }

    function latestVersionAppBase(bytes32 appId) public view returns (address base) {
        Repo repo = Repo(PublicResolver(ens.resolver(appId)).addr(appId));
        (,base,) = repo.getLatest();

        return base;
    }
}


contract Template is TemplateBase {
    MiniMeTokenFactory tokenFactory;

    uint64 constant PCT = 10 ** 16;
    address constant ANY_ENTITY = address(-1);

    constructor(ENS ens) TemplateBase(DAOFactory(0), ens) public {
        tokenFactory = new MiniMeTokenFactory();
    }

    function createToken(string _name, uint8 _decimals, string _symbol, bool _transferable) public {
      MiniMeToken token = tokenFactory.createCloneToken(MiniMeToken(0), 0, _name, _decimals, _symbol, _transferable);
      _cacheToken(token, msg.sender);
    }

    function newInstance(address[] _holders, string _guardianTokenName, string _currencyTokenName) public {
    /* function newInstance() public { */
        Kernel dao = fac.newDAO(this);
        ACL acl = ACL(dao.acl());
        acl.createPermission(this, dao, dao.APP_MANAGER_ROLE(), this);

        bytes32 airdropAppId = keccak256(abi.encodePacked(apmNamehash("open"), keccak256("airdrop-app")));
        bytes32 votingAppId = apmNamehash("voting");
        bytes32 tokenManagerAppId = apmNamehash("token-manager");

        Airdrop airdrop = Airdrop(dao.newAppInstance(airdropAppId, latestVersionAppBase(airdropAppId)));
        Voting voting = Voting(dao.newAppInstance(votingAppId, latestVersionAppBase(votingAppId)));
        TokenManager guardianTokenManager = TokenManager(dao.newAppInstance(tokenManagerAppId, latestVersionAppBase(tokenManagerAppId)));
        TokenManager currencyTokenManager = TokenManager(dao.newAppInstance(tokenManagerAppId, latestVersionAppBase(tokenManagerAppId)));

        /* MiniMeToken token = tokenFactory.createCloneToken(MiniMeToken(0), 0, "Guardian", 18, "GUARD", false); */
        MiniMeToken guardianToken = _popTokenCache(msg.sender, _guardianTokenName);
        guardianToken.changeController(guardianTokenManager);

        MiniMeToken currencyToken = _popTokenCache(msg.sender, _currencyTokenName);
        currencyToken.changeController(currencyTokenManager);

        // Initialize apps
        guardianTokenManager.initialize(guardianToken, false, 0);
        emit InstalledApp(guardianTokenManager, tokenManagerAppId);
        currencyTokenManager.initialize(currencyToken, true, 0);
        emit InstalledApp(currencyTokenManager, tokenManagerAppId);
        voting.initialize(guardianToken, uint64(60*10**16), uint64(15*10**16), uint64(1 days));
        emit InstalledApp(voting, votingAppId);
        airdrop.initialize(currencyTokenManager);
        emit InstalledApp(airdrop, airdropAppId);

        acl.createPermission(guardianTokenManager, voting, voting.CREATE_VOTES_ROLE(), voting);
        acl.createPermission(voting, guardianTokenManager, guardianTokenManager.BURN_ROLE(), voting);
        acl.createPermission(voting, airdrop, airdrop.START_ROLE(), voting);
        acl.createPermission(this, guardianTokenManager, guardianTokenManager.MINT_ROLE(), this);
        acl.createPermission(airdrop, currencyTokenManager, currencyTokenManager.MINT_ROLE(), voting);

        _mintHolders(guardianTokenManager, _holders);

        // Clean up permissions
        acl.grantPermission(voting, guardianTokenManager, guardianTokenManager.MINT_ROLE());
        acl.revokePermission(this, guardianTokenManager, guardianTokenManager.MINT_ROLE());
        acl.setPermissionManager(voting, guardianTokenManager, guardianTokenManager.MINT_ROLE());

        acl.grantPermission(voting, dao, dao.APP_MANAGER_ROLE());
        acl.revokePermission(this, dao, dao.APP_MANAGER_ROLE());
        acl.setPermissionManager(voting, dao, dao.APP_MANAGER_ROLE());

        acl.grantPermission(voting, acl, acl.CREATE_PERMISSIONS_ROLE());
        acl.revokePermission(this, acl, acl.CREATE_PERMISSIONS_ROLE());
        acl.setPermissionManager(voting, acl, acl.CREATE_PERMISSIONS_ROLE());

        emit DeployDao(dao);
    }

    function _mintHolders(TokenManager _tokenManager, address[] _holders) internal {
        for (uint i=0; i<_holders.length; i++) {
            _tokenManager.mint(_holders[i], 1e18); // Give 1 token to each holder
        }
    }

}
