pragma solidity ^0.4.24;

import "@aragon/os/contracts/kernel/Kernel.sol";
import "@aragon/os/contracts/acl/ACL.sol";
import "@aragon/os/contracts/apm/Repo.sol";
import "@aragon/os/contracts/lib/ens/ENS.sol";
import "@aragon/os/contracts/lib/ens/PublicResolver.sol";

import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-voting/contracts/Voting.sol";

import "@daonuts/airdrop-duo/contracts/AirdropDuo.sol";
import "@daonuts/challenge/contracts/Challenge.sol";
import "@daonuts/subscribe/contracts/Subscribe.sol";
import "@daonuts/tipping/contracts/Tipping.sol";

contract TemplateApps {
    ENS public ens;

    uint TOKEN_UNIT;
    address ANY_ENTITY;

    bytes32 airdropDuoAppId;
    bytes32 challengeAppId;
    bytes32 subscribeAppId;
    bytes32 tippingAppId;

    event InstalledApp(address appProxy, bytes32 appId);
    event Debug(address debug);

    constructor(ENS _ens) public {
        ens = _ens;
    }

    function install(
        Kernel _dao, Voting _voting, TokenManager _contribManager, TokenManager _currencyManager,
        AirdropDuo _airdrop, Challenge _challenge, Subscribe _subscribe, Tipping _tipping
    ) public {
        ACL acl = ACL(_dao.acl());

        _airdrop.initialize(_contribManager, _currencyManager);
        _challenge.initialize(
          _currencyManager, 100*TOKEN_UNIT, 10*TOKEN_UNIT, 50*TOKEN_UNIT,
          uint64(1 minutes), uint64(1 minutes), uint64(1 minutes)
        );
        _subscribe.initialize(_currencyManager, 10000*TOKEN_UNIT, uint64(30 days));
        _tipping.initialize(_currencyManager.token());

        acl.createPermission(_airdrop, _contribManager, _contribManager.MINT_ROLE(), msg.sender);
        acl.createPermission(_airdrop, _currencyManager, _currencyManager.MINT_ROLE(), msg.sender);
        acl.createPermission(_challenge, _airdrop, _airdrop.START_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, _challenge, _challenge.PROPOSE_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, _challenge, _challenge.CHALLENGE_ROLE(), msg.sender);
        acl.createPermission(_voting, _challenge, _challenge.SUPPORT_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, _subscribe, _subscribe.SET_PRICE_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, _tipping, _tipping.NONE(), msg.sender);

        /* _tokenPermissions(_dao, _voting, _contribManager, _currencyManager);
        _challengePermissions(_dao, _voting, _currencyManager, challenge);
        _subscribePermissions(_dao, _voting, _currencyManager, subscribe);
        _airdropPermissions(_dao, _voting, _contribManager, _currencyManager, airdrop);
        _cleanup(_dao, _voting, _contribManager, _currencyManager, tipping); */
    }

    function _tokenPermissions(
        Kernel _dao, Voting _voting, TokenManager _contribManager, TokenManager _currencyManager
    ) internal {
        ACL acl = ACL(_dao.acl());
        bytes32 MINT_ROLE = _contribManager.MINT_ROLE();
        bytes32 BURN_ROLE = _contribManager.BURN_ROLE();

        acl.createPermission(_contribManager, _voting, _voting.CREATE_VOTES_ROLE(), _voting);
        acl.createPermission(_voting, _contribManager, BURN_ROLE, _voting);
        acl.createPermission(this, _contribManager, MINT_ROLE, this);

        address[] memory holders = new address[](1);
        holders[0] = msg.sender;
        _mintHolders(_contribManager, holders);

        acl.revokePermission(this, _contribManager, MINT_ROLE);
    }

    function _challengePermissions(
        Kernel _dao, Voting _voting, TokenManager _currencyManager, Challenge _challenge
    ) internal {
        ACL acl = ACL(_dao.acl());

        acl.createPermission(_challenge, _currencyManager, _currencyManager.MINT_ROLE(), this);
        acl.createPermission(_challenge, _currencyManager, _currencyManager.BURN_ROLE(), this);
        acl.createPermission(ANY_ENTITY, _challenge, _challenge.PROPOSE_ROLE(), _voting);
        acl.createPermission(ANY_ENTITY, _challenge, _challenge.CHALLENGE_ROLE(), _voting);
        acl.createPermission(_voting, _challenge, _challenge.SUPPORT_ROLE(), _voting);
        acl.createPermission(_challenge, _challenge, _challenge.MODIFY_PARAMETER_ROLE(), _voting);
    }

    function _subscribePermissions(
        Kernel _dao, Voting _voting, TokenManager _currencyManager, Subscribe _subscribe
    ) internal {
        ACL acl = ACL(_dao.acl());

        acl.grantPermission(_subscribe, _currencyManager, _currencyManager.BURN_ROLE());
        acl.createPermission(_voting, _subscribe, _subscribe.SET_PRICE_ROLE(), _voting);
        acl.createPermission(_voting, _subscribe, _subscribe.SET_DURATION_ROLE(), _voting);
    }

    function _airdropPermissions(
        Kernel _dao, Voting _voting, TokenManager _contribManager, TokenManager _currencyManager, AirdropDuo _airdrop
    ) internal {
        ACL acl = ACL(_dao.acl());

        acl.grantPermission(_airdrop, _contribManager, _contribManager.MINT_ROLE());
        acl.grantPermission(_airdrop, _currencyManager, _currencyManager.MINT_ROLE());
        acl.createPermission(_voting, _airdrop, _airdrop.START_ROLE(), this);
        acl.setPermissionManager(_voting, _airdrop, _airdrop.START_ROLE());
    }

    function _cleanup(
        Kernel _dao, Voting _voting, TokenManager _contribManager, TokenManager _currencyManager, Tipping tipping
    ) internal {
        ACL acl = ACL(_dao.acl());
        bytes32 APP_MANAGER_ROLE = _dao.APP_MANAGER_ROLE();
        bytes32 CREATE_PERMISSIONS_ROLE = acl.CREATE_PERMISSIONS_ROLE();
        bytes32 MINT_ROLE = _contribManager.MINT_ROLE();
        bytes32 BURN_ROLE = _contribManager.BURN_ROLE();

        acl.createPermission(_voting, tipping, tipping.NONE(), _voting);

        acl.setPermissionManager(_voting, _currencyManager, MINT_ROLE);
        acl.setPermissionManager(_voting, _currencyManager, BURN_ROLE);
        acl.setPermissionManager(_voting, _contribManager, MINT_ROLE);
        acl.setPermissionManager(_voting, _contribManager, BURN_ROLE);

        acl.grantPermission(_voting, _dao, APP_MANAGER_ROLE);
        acl.revokePermission(this, _dao, APP_MANAGER_ROLE);
        acl.setPermissionManager(_voting, _dao, APP_MANAGER_ROLE);

        acl.grantPermission(_voting, acl, CREATE_PERMISSIONS_ROLE);
        acl.revokePermission(this, acl, CREATE_PERMISSIONS_ROLE);
        acl.setPermissionManager(_voting, acl, CREATE_PERMISSIONS_ROLE);
    }

    function latestVersionAppBase(bytes32 appId) public view returns (address base) {
        Repo repo = Repo(PublicResolver(ens.resolver(appId)).addr(appId));
        (,base,) = repo.getLatest();

        return base;
    }

    function _mintHolders(TokenManager _tokenManager, address[] _holders) internal {
        for (uint i=0; i<_holders.length; i++) {
            _tokenManager.mint(_holders[i], 1 * 10**18); // Give 1 token to each holder
        }
    }

}
