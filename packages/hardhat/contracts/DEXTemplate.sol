// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

/**
 * @title DEX Template
 * @author stevepham.eth and m00npapi.eth
 * @notice Empty DEX.sol that just outlines what features could be part of the challenge (up to you!)
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this branch/repo. Also return variable names that may need to be specified exactly may be referenced (if you are confused, see solutions folder in this repo and/or cross reference with front-end code).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract

    uint256 public totalLiquidity;
    mapping (address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(uint256 ethAmount, uint256 tokenAmount, address swapper);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(uint256 tokenAmount, uint256 ethAmount, address swapper);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided(uint256 ethAmount, uint256 tokenAmount, address provider);

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved(uint256 ethAmount, uint256 tokenAmount, address provider);

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) {
        token = IERC20(token_addr); //specifies the token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return initLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256 initLiquidity) {
        require(totalLiquidity == 0, "Contract has already been initialized");
        totalLiquidity = msg.value;
        liquidity[msg.sender] = totalLiquidity;
        token.transferFrom(msg.sender, address(this), tokens);
        initLiquidity = totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev input amount (nett) * current output reserves / new input reserve 
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        uint256 nett_xInput = xInput.mul(997);
        uint256 numerator = nett_xInput.mul(yReserves);
        uint256 divisor = xReserves.mul(1000).add(nett_xInput);
        return numerator.div(divisor);
    }

    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     */
    function getLiquidity(address lp) external view returns (uint256) {
        return liquidity[lp];
    }

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() external payable returns (uint256 tokenOutput) {
        tokenOutput = price(msg.value, address(this).balance.sub(msg.value), token.balanceOf(address(this)));
        token.transfer(msg.sender, tokenOutput);
        emit EthToTokenSwap(msg.value, tokenOutput, msg.sender);
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) external returns (uint256 ethOutput) {
        ethOutput = price(tokenInput, token.balanceOf(address(this)), address(this).balance);
        token.transferFrom(msg.sender, address(this), tokenInput);
        msg.sender.call{value: ethOutput}("");
        emit TokenToEthSwap(tokenInput, ethOutput, msg.sender);
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() external payable returns (uint256 tokensDeposited) {
        uint256 ethLiquidity = address(this).balance.sub(msg.value);
        tokensDeposited = msg.value.mul(token.balanceOf(address(this))).div(ethLiquidity); 
        uint256 liqAdded = msg.value.mul(totalLiquidity).div(ethLiquidity); 
        totalLiquidity = totalLiquidity.add(liqAdded);
        liquidity[msg.sender] = liquidity[msg.sender].add(liqAdded);
        token.transferFrom(msg.sender, address(this), tokensDeposited);
        emit LiquidityProvided(msg.value, tokensDeposited, msg.sender);
    }

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount) external returns (uint256 eth_amount, uint256 token_amount) {
        eth_amount = amount.mul(address(this).balance) / totalLiquidity;
        require(liquidity[msg.sender] >= eth_amount, "You don't have that much liquidity in this pool");
        token_amount = amount.mul(token.balanceOf(address(this))).div(totalLiquidity); 
        totalLiquidity = totalLiquidity.sub(eth_amount);
        liquidity[msg.sender] = liquidity[msg.sender].sub(eth_amount);
        msg.sender.call{value: eth_amount}("");
        token.transfer(msg.sender, token_amount);
        emit LiquidityRemoved(eth_amount, token_amount, msg.sender);
    }
}
