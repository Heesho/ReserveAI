// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {

    uint256 public constant MAX_SUPPLY = 21000000 * (10**18);
    uint256 public immutable INCEPTION;

    constructor(string memory name, string memory symbol)
        ERC20(name, symbol)
    {
        INCEPTION = block.timestamp;
        _mint(msg.sender, (100000) * (10**18));
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}