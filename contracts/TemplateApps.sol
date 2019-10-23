pragma solidity ^0.4.24;

import "@aragon/os/contracts/kernel/Kernel.sol";
import "@aragon/os/contracts/acl/ACL.sol";
import "@aragon/os/contracts/apm/Repo.sol";
import "@aragon/os/contracts/lib/ens/ENS.sol";
import "@aragon/os/contracts/lib/ens/PublicResolver.sol";

import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-voting/contracts/Voting.sol";

import "@1hive/airdrop-app/contracts/Airdrop.sol";

import "@daonuts/subscription-app/contracts/Subscription.sol";

contract TemplateApps {
    ENS public ens;

    //namehash("airdrop-app.open.aragonpm.eth")
    bytes32 constant airdropAppId = 0x356065541af8b2e74db8b224183c7552774bd8246b1191179719921d9c97d4c2;
    //namehash("subscription-app.open.aragonpm.eth")
    bytes32 constant subscriptionAppId = 0xd386d2731a66fd3903d5a74ff0ea1dbb2bdb63c1a71340c2b430496acf99d507;

    event InstalledApp(address appProxy, bytes32 appId);

    constructor(ENS _ens) public {
        ens = _ens;
    }

    function install(Kernel _dao, Voting _voting, TokenManager _currencyTokenManager) public {
        ACL acl = ACL(_dao.acl());

        Airdrop airdrop = Airdrop(_dao.newAppInstance(airdropAppId, latestVersionAppBase(airdropAppId)));
        Subscription subscription = Subscription(_dao.newAppInstance(subscriptionAppId, latestVersionAppBase(subscriptionAppId)));

        airdrop.initialize(_currencyTokenManager);
        emit InstalledApp(airdrop, airdropAppId);
        subscription.initialize(_currencyTokenManager, 10000e18, 30 days);
        emit InstalledApp(subscription, subscriptionAppId);

        _permissions(_dao, acl, _voting, _currencyTokenManager, airdrop, subscription);
    }

    function _permissions(
        Kernel _dao, ACL _acl, Voting _voting, TokenManager _currencyTokenManager, Airdrop _airdrop, Subscription _subscription
    ) internal {

        bytes32 APP_MANAGER_ROLE = _dao.APP_MANAGER_ROLE();
        bytes32 CREATE_PERMISSIONS_ROLE = _acl.CREATE_PERMISSIONS_ROLE();

        _acl.createPermission(_airdrop, _currencyTokenManager, _currencyTokenManager.MINT_ROLE(), _voting);
        _acl.createPermission(_subscription, _currencyTokenManager, _currencyTokenManager.BURN_ROLE(), _voting);
        _acl.createPermission(_voting, _airdrop, _airdrop.START_ROLE(), _voting);
        _acl.createPermission(_voting, _subscription, _subscription.SET_PRICE_ROLE(), _voting);
        _acl.createPermission(_voting, _subscription, _subscription.SET_DURATION_ROLE(), _voting);

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
