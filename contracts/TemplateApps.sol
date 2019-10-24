pragma solidity ^0.4.24;

import "@aragon/os/contracts/kernel/Kernel.sol";
import "@aragon/os/contracts/acl/ACL.sol";
import "@aragon/os/contracts/apm/Repo.sol";
import "@aragon/os/contracts/lib/ens/ENS.sol";
import "@aragon/os/contracts/lib/ens/PublicResolver.sol";

import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-voting/contracts/Voting.sol";

import "@daonuts/airdrop-duo-app/contracts/AirdropDuo.sol";
import "@daonuts/challenge-app/contracts/Challenge.sol";
import "@daonuts/subscribe-app/contracts/Subscribe.sol";
import "@daonuts/tip-app/contracts/Tip.sol";

contract TemplateApps {
    ENS public ens;

    uint constant TOKEN_UNIT = 10 ** 18;
    address constant ANY_ENTITY = address(-1);

    //namehash("airdrop-duo-app.open.aragonpm.eth")
    bytes32 constant airdropDuoAppId = 0xa9e4c5b47fe3f0e61f6a7a045848bf59d44a5eaad3fbb6274929030a2030797d;
    //namehash("challenge-app.open.aragonpm.eth")
    bytes32 constant challengeAppId = 0x67c5438d71d05e58f99e88d6fb61ea5356b0f57106d3aba65c823267cc1cd07e;
    //namehash("subscribe-app.open.aragonpm.eth")
    bytes32 constant subscribeAppId = 0xb6461185219d266fa4eb5f1acad9b08a010bfd1e1f6a45fe3e169f161d8d5af1;
    //namehash("tip-app.open.aragonpm.eth")
    bytes32 constant tipAppId = 0xc75d5f393be107a3b3f2b5ed1c1fa53b7fe1f347bac8cd9de9158b94312bfd59;

    event InstalledApp(address appProxy, bytes32 appId);

    constructor(ENS _ens) public {
        ens = _ens;
    }

    function install(
        Kernel _dao, Voting _voting, TokenManager _contribManager, TokenManager _currencyManager
    ) public {
        ACL acl = ACL(_dao.acl());

        AirdropDuo airdrop = AirdropDuo(_dao.newAppInstance(airdropDuoAppId, latestVersionAppBase(airdropDuoAppId)));
        Challenge challenge = Challenge(_dao.newAppInstance(challengeAppId, latestVersionAppBase(challengeAppId)));
        Subscribe subscribe = Subscribe(_dao.newAppInstance(subscribeAppId, latestVersionAppBase(subscribeAppId)));
        Tip tip = Tip(_dao.newAppInstance(tipAppId, latestVersionAppBase(tipAppId)));

        airdrop.initialize(_contribManager, _currencyManager);
        emit InstalledApp(airdrop, airdropDuoAppId);
        challenge.initialize(
          _currencyManager, 100*TOKEN_UNIT, 10*TOKEN_UNIT, 50*TOKEN_UNIT,
          uint64(1 minutes), uint64(1 minutes), uint64(1 minutes)
        );
        emit InstalledApp(challenge, challengeAppId);
        subscribe.initialize(_currencyManager, 10000*TOKEN_UNIT, uint64(30 days));
        emit InstalledApp(subscribe, subscribeAppId);
        tip.initialize(_currencyManager.token());
        emit InstalledApp(tip, tipAppId);

        _permissions(_dao, acl, _voting, _contribManager, _currencyManager, airdrop, challenge, subscribe, tip);
    }

    function _permissions(
        Kernel _dao, ACL _acl, Voting _voting, TokenManager _contribManager,
        TokenManager _currencyManager, AirdropDuo _airdrop, Challenge _challenge,
        Subscribe _subscribe, Tip tip
    ) internal {

        bytes32 APP_MANAGER_ROLE = _dao.APP_MANAGER_ROLE();
        bytes32 CREATE_PERMISSIONS_ROLE = _acl.CREATE_PERMISSIONS_ROLE();
        bytes32 CURRENCY_MINT_ROLE = _currencyManager.MINT_ROLE();
        bytes32 CURRENCY_BURN_ROLE = _currencyManager.BURN_ROLE();

        _acl.createPermission(_challenge, _currencyManager, CURRENCY_MINT_ROLE, this);
        _acl.createPermission(_challenge, _currencyManager, CURRENCY_BURN_ROLE, this);
        _acl.createPermission(_airdrop, _contribManager, _contribManager.MINT_ROLE(), _voting);
        _acl.grantPermission(_airdrop, _currencyManager, CURRENCY_MINT_ROLE);
        _acl.grantPermission(_subscribe, _currencyManager, CURRENCY_BURN_ROLE);
        _acl.createPermission(_voting, tip, tip.NONE(), _voting);

        _acl.createPermission(_challenge, _airdrop, _airdrop.START_ROLE(), _voting);
        _acl.createPermission(_challenge, _subscribe, _subscribe.SET_PRICE_ROLE(), _voting);
        _acl.createPermission(_challenge, _subscribe, _subscribe.SET_DURATION_ROLE(), _voting);

        _acl.createPermission(ANY_ENTITY, _challenge, _challenge.PROPOSE_ROLE(), _voting);
        _acl.createPermission(ANY_ENTITY, _challenge, _challenge.CHALLENGE_ROLE(), _voting);
        _acl.createPermission(_voting, _challenge, _challenge.SUPPORT_ROLE(), _voting);
        _acl.createPermission(_challenge, _challenge, _challenge.MODIFY_PARAMETER_ROLE(), _voting);

        _acl.setPermissionManager(_voting, _currencyManager, CURRENCY_MINT_ROLE);
        _acl.setPermissionManager(_voting, _currencyManager, CURRENCY_BURN_ROLE);

        _acl.grantPermission(_voting, _dao, APP_MANAGER_ROLE);
        _acl.revokePermission(this, _dao, APP_MANAGER_ROLE);
        _acl.setPermissionManager(_voting, _dao, APP_MANAGER_ROLE);

        _acl.grantPermission(_voting, _acl, CREATE_PERMISSIONS_ROLE);
        _acl.revokePermission(this, _acl, CREATE_PERMISSIONS_ROLE);
        _acl.setPermissionManager(_voting, _acl, CREATE_PERMISSIONS_ROLE);
    }

    function latestVersionAppBase(bytes32 appId) public view returns (address base) {
        Repo repo = Repo(PublicResolver(ens.resolver(appId)).addr(appId));
        (,base,) = repo.getLatest();

        return base;
    }

}
