pragma solidity ^0.4.24;

import "@aragon/os/contracts/kernel/Kernel.sol";
import "@aragon/os/contracts/acl/ACL.sol";

import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";
import "@aragon/apps-token-manager/contracts/TokenManager.sol";
/* import "@aragon/apps-voting/contracts/Voting.sol"; */

import "@daonuts/token/contracts/Token.sol";
import "@daonuts/airdrop-duo/contracts/AirdropDuo.sol";
import "@daonuts/challenge/contracts/Challenge.sol";
import "@daonuts/harberger/contracts/Harberger.sol";
import "@daonuts/subscribe/contracts/Subscribe.sol";
import "@daonuts/tipping/contracts/Tipping.sol";
import "@daonuts/capped-voting/contracts/CappedVoting.sol";

contract TemplateApps {
    uint constant TOKEN_UNIT = 10 ** 18;
    address constant ANY_ENTITY = address(-1);
    bytes32 constant MINT_ROLE = keccak256("MINT_ROLE");
    bytes32 constant BURN_ROLE = keccak256("BURN_ROLE");

    bytes32 airdropDuoAppId;
    bytes32 challengeAppId;
    bytes32 subscribeAppId;
    bytes32 tippingAppId;

    event InstalledApp(address appProxy, bytes32 appId);

    function install(
        Kernel dao, CappedVoting voting, TokenManager contribManager,
        TokenManager currencyManager, AirdropDuo airdrop, Challenge challenge,
        Harberger harberger, Subscribe subscribe, Tipping tipping
    ) public {
        ACL acl = ACL(dao.acl());

        Token contrib = Token(contribManager.token());
        Token currency = Token(currencyManager.token());

        voting.initialize(contrib, currency, uint64(60 * 10**16), uint64(15 * 10**16), uint64(1 days));
        challenge.initialize(
          currencyManager, 100*TOKEN_UNIT, 10*TOKEN_UNIT, 50*TOKEN_UNIT,
          uint64(1 minutes), uint64(1 minutes), uint64(1 minutes)
        );
        harberger.initialize(currencyManager);
        subscribe.initialize(currencyManager, 10000*TOKEN_UNIT, uint64(30 days));
        tipping.initialize(currencyManager.token());

        acl.createPermission(ANY_ENTITY, harberger, harberger.PURCHASE_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, harberger, MINT_ROLE, msg.sender);
        acl.createPermission(ANY_ENTITY, harberger, BURN_ROLE, msg.sender);
        acl.createPermission(ANY_ENTITY, harberger, harberger.MODIFY_ROLE(), msg.sender);

        acl.createPermission(ANY_ENTITY, contribManager, MINT_ROLE, msg.sender);

        acl.createPermission(ANY_ENTITY, currencyManager, MINT_ROLE, this);
        acl.grantPermission(airdrop, currencyManager, MINT_ROLE);
        acl.grantPermission(challenge, currencyManager, MINT_ROLE);

        acl.createPermission(airdrop, currencyManager, BURN_ROLE, this);
        acl.grantPermission(challenge, currencyManager, BURN_ROLE);
        acl.grantPermission(harberger, currencyManager, BURN_ROLE);
        acl.grantPermission(subscribe, currencyManager, BURN_ROLE);

        acl.createPermission(ANY_ENTITY, voting, voting.CREATE_VOTES_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, airdrop, airdrop.START_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, challenge, challenge.PROPOSE_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, challenge, challenge.CHALLENGE_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, challenge, challenge.SUPPORT_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, subscribe, subscribe.SET_PRICE_ROLE(), msg.sender);
        acl.createPermission(ANY_ENTITY, tipping, tipping.NONE(), msg.sender);
    }

}
