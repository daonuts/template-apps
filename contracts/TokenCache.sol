pragma solidity ^0.4.24;

import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";

contract TokenCache {
    mapping (address => mapping (bytes32 => address) ) internal tokenCache;

    function _cacheToken(MiniMeToken _token, address _owner) internal {
        tokenCache[_owner][keccak256(_token.name())] = _token;
    }

    function _popTokenCache(address _owner, string _name) internal returns (MiniMeToken) {
        bytes32 nameHash = keccak256(_name);
        /* require(tokenCache[_owner][nameHash] != address(0), "TEMPLATE_MISSING_TOKEN_CACHE"); */

        MiniMeToken token = MiniMeToken(tokenCache[_owner][nameHash]);
        delete tokenCache[_owner][nameHash];
        return token;
    }
}
