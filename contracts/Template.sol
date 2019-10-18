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

import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-voting/contracts/Voting.sol";
import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";

import "@1hive/airdrop-app/contracts/Airdrop.sol";

import "./TokenCache.sol";

contract Template is TokenCache {
    ENS public ens;
    DAOFactory public fac;
    MiniMeTokenFactory tokenFactory;

    //namehash("bare-kit.aragonpm.eth")
    bytes32 constant bareKitId = 0xf5ac5461dc6e4b6382eea8c2bc0d0d47c346537a4cb19fba07e96d7ef0edc5c0;
    //namehash("airdrop-app.open.aragonpm.eth")
    bytes32 constant airdropAppId = 0x356065541af8b2e74db8b224183c7552774bd8246b1191179719921d9c97d4c2;
    //namehash("voting.aragonpm.eth")
    bytes32 constant votingAppId = 0x9fa3927f639745e587912d4b0fea7ef9013bf93fb907d29faeab57417ba6e1d4;
    //namehash("token-manageraragonpm.eth")
    bytes32 constant tokenManagerAppId = 0x35d4a35860c750bac3afb42b11e94da331fddad24975c61c28fb569cd5c0c5cd;

    event DeployDao(address dao);
    event InstalledApp(address appProxy, bytes32 appId);

    constructor(ENS _ens) public {
        ens = _ens;
        fac = Template(latestVersionAppBase(bareKitId)).fac();
        tokenFactory = new MiniMeTokenFactory();
    }

    function createToken(string _name, uint8 _decimals, string _symbol, bool _transferable) public {
      MiniMeToken token = tokenFactory.createCloneToken(MiniMeToken(0), 0, _name, _decimals, _symbol, _transferable);
      _cacheToken(token, msg.sender);
    }

    function newInstance(address[] _holders, string _guardianTokenName, string _currencyTokenName) public {
    /* function newInstance(string _guardianTokenName, string _currencyTokenName) public { */
        Kernel dao = fac.newDAO(this);
        ACL acl = ACL(dao.acl());
        acl.createPermission(this, dao, dao.APP_MANAGER_ROLE(), this);

        Voting voting = Voting(dao.newAppInstance(votingAppId, latestVersionAppBase(votingAppId)));
        Airdrop airdrop = Airdrop(dao.newAppInstance(airdropAppId, latestVersionAppBase(airdropAppId)));

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
        voting.initialize(guardianToken, uint64(60 * 10**16), uint64(15 * 10**16), uint64(1 days));
        emit InstalledApp(voting, votingAppId);
        airdrop.initialize(currencyTokenManager);
        emit InstalledApp(airdrop, airdropAppId);

        _permissions(dao, acl, voting, guardianTokenManager, _holders, currencyTokenManager, airdrop);
    }

    function _permissions(
        Kernel _dao, ACL _acl, Voting _voting, TokenManager _guardianTokenManager,
        address[] _holders, TokenManager _currencyTokenManager, Airdrop _airdrop
    ) internal {

        bytes32 APP_MANAGER_ROLE = _dao.APP_MANAGER_ROLE();
        bytes32 CREATE_PERMISSIONS_ROLE = _acl.CREATE_PERMISSIONS_ROLE();
        bytes32 MINT_ROLE = _guardianTokenManager.MINT_ROLE();

        _acl.createPermission(_voting, _airdrop, _airdrop.START_ROLE(), _voting);
        _acl.createPermission(_airdrop, _currencyTokenManager, _currencyTokenManager.MINT_ROLE(), _voting);
        _acl.createPermission(_guardianTokenManager, _voting, _voting.CREATE_VOTES_ROLE(), _voting);
        _acl.createPermission(_voting, _guardianTokenManager, _guardianTokenManager.BURN_ROLE(), _voting);

        _acl.createPermission(this, _guardianTokenManager, MINT_ROLE, this);
        _mintHolders(_guardianTokenManager, _holders);

        _acl.grantPermission(_voting, _guardianTokenManager, MINT_ROLE);
        _acl.revokePermission(this, _guardianTokenManager, MINT_ROLE);
        _acl.setPermissionManager(_voting, _guardianTokenManager, MINT_ROLE);

        _acl.grantPermission(_voting, _dao, APP_MANAGER_ROLE);
        _acl.revokePermission(this, _dao, APP_MANAGER_ROLE);
        _acl.setPermissionManager(_voting, _dao, APP_MANAGER_ROLE);

        _acl.grantPermission(_voting, _acl, CREATE_PERMISSIONS_ROLE);
        _acl.revokePermission(this, _acl, CREATE_PERMISSIONS_ROLE);
        _acl.setPermissionManager(_voting, _acl, CREATE_PERMISSIONS_ROLE);

        emit DeployDao(_dao);
    }

    function _mintHolders(TokenManager _tokenManager, address[] _holders) internal {
        for (uint i=0; i<_holders.length; i++) {
            _tokenManager.mint(_holders[i], 1e18); // Give 1 token to each holder
        }
    }

    function latestVersionAppBase(bytes32 appId) public view returns (address base) {
        Repo repo = Repo(PublicResolver(ens.resolver(appId)).addr(appId));
        (,base,) = repo.getLatest();

        return base;
    }

}
