pragma solidity ^0.4.24;

import "@aragon/os/contracts/kernel/Kernel.sol";
import "@aragon/os/contracts/acl/ACL.sol";

import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";
import "@aragon/apps-token-manager/contracts/TokenManager.sol";
import "@aragon/apps-agent/contracts/Agent.sol";
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

    function installSetA(
        Kernel dao, CappedVoting voting, TokenManager contribManager,
        TokenManager currencyManager, AirdropDuo airdrop, Challenge challenge
    ) public {
        ACL acl = ACL(dao.acl());

        Token contrib = Token(contribManager.token());
        Token currency = Token(currencyManager.token());

        voting.initialize(contrib, currency, uint64(50 * 10**16), uint64(10 * 10**16), uint64(7 days));
        challenge.initialize(
          currencyManager, 200000*TOKEN_UNIT, 10000*TOKEN_UNIT, 80000*TOKEN_UNIT,
          uint64(7 days), uint64(14 days), uint64(30 minutes)
        );

        acl.createPermission(airdrop, contribManager, MINT_ROLE, msg.sender);

        acl.createPermission(airdrop, currencyManager, MINT_ROLE, this);
        acl.grantPermission(challenge, currencyManager, MINT_ROLE);
        acl.setPermissionManager(msg.sender, currencyManager, MINT_ROLE);

        acl.createPermission(challenge, currencyManager, BURN_ROLE, this);

        acl.createPermission(contribManager, voting, voting.CREATE_VOTES_ROLE(), msg.sender);
        acl.createPermission(msg.sender, voting, voting.MODIFY_SUPPORT_ROLE(), msg.sender);
        acl.createPermission(msg.sender, voting, voting.MODIFY_QUORUM_ROLE(), msg.sender);

        acl.createPermission(challenge, airdrop, airdrop.START_ROLE(), msg.sender);
        acl.createPermission(msg.sender, challenge, challenge.PROPOSE_ROLE(), msg.sender);
        acl.createPermission(contribManager, challenge, challenge.CHALLENGE_ROLE(), msg.sender);
        acl.createPermission(voting, challenge, challenge.SUPPORT_ROLE(), msg.sender);
    }

    function installSetB(
        Kernel dao, TokenManager currencyManager, Harberger harberger, Subscribe subscribe, Tipping tipping, Agent agent
    ) public {
        ACL acl = ACL(dao.acl());

        harberger.initialize(currencyManager);
        subscribe.initialize(currencyManager, 5000*TOKEN_UNIT, uint64(30 days));
        tipping.initialize(currencyManager.token());
        agent.initialize();

        // 'this' is already currencyManager.BURN_ROLE() manager from installSetA
        acl.grantPermission(harberger, currencyManager, BURN_ROLE);
        acl.grantPermission(subscribe, currencyManager, BURN_ROLE);
        acl.setPermissionManager(msg.sender, currencyManager, BURN_ROLE);

        acl.createPermission(ANY_ENTITY, harberger, harberger.PURCHASE_ROLE(), msg.sender);
        acl.createPermission(msg.sender, harberger, MINT_ROLE, msg.sender);
        acl.createPermission(msg.sender, harberger, BURN_ROLE, msg.sender);
        acl.createPermission(msg.sender, harberger, harberger.MODIFY_ROLE(), msg.sender);

        acl.createPermission(msg.sender, subscribe, subscribe.SET_PRICE_ROLE(), msg.sender);
        acl.createPermission(msg.sender, subscribe, subscribe.SET_DURATION_ROLE(), msg.sender);

        acl.createPermission(0x0, tipping, 0x0, 0x0);
        acl.createPermission(msg.sender, agent, agent.EXECUTE_ROLE(), msg.sender);
    }

}
