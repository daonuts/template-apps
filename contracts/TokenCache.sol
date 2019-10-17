pragma solidity ^0.4.24;

import "@aragon/apps-shared-minime/contracts/MiniMeToken.sol";

contract TokenCache {
    string constant private ERROR_MISSING_TOKEN_CACHE = "TEMPLATE_MISSING_TOKEN_CACHE";

    mapping (address => mapping (bytes32 => address) ) internal tokenCache;

    function _cacheToken(MiniMeToken _token, address _owner) internal {
        tokenCache[_owner][keccak256(abi.encodePacked(_token.name()))] = _token;
    }

    function _popTokenCache(address _owner, string _name) internal returns (MiniMeToken) {
        bytes32 nameHash = keccak256(abi.encodePacked(_name));
        require(tokenCache[_owner][nameHash] != address(0), ERROR_MISSING_TOKEN_CACHE);

        MiniMeToken token = MiniMeToken(tokenCache[_owner][nameHash]);
        delete tokenCache[_owner][nameHash];
        return token;
    }
}
