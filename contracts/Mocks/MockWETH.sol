pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20("WETH", "WETH") {

    function mint(address to, uint256 value) external returns (bool) {
        _mint(to, value);
        return true;
    }
}
