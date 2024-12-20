// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @custom:security-contact your-email@example.com
contract PortraitPaymentReceiverBase is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                      VARIABLES
    //////////////////////////////////////////////////////////////*/

    IERC20 public usdcToken;
    IERC20 public daiToken;
    IERC20 public usdtToken;
    AggregatorV2V3Interface internal priceFeed;
    AggregatorV2V3Interface internal sequencerUptimeFeed;

    uint256 public paymentAmountUSD;

    uint256 public UNIT_FACTOR_USDC;
    uint256 public UNIT_FACTOR_DAI;
    uint256 public UNIT_FACTOR_USDT;

    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /// @dev Mapping from Ethereum address to boolean indicating if the address has paid.
    mapping(address => bool) private hasPaid;

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Revert with `InsufficientPayment` if the sent amount is less than required.
    error InsufficientPayment();

    /// @dev Revert with `InvalidAddress` if a zero address is used.
    error InvalidAddress();

    /// @dev Revert with `SequencerDown` if the L2 sequencer is down.
    error SequencerDown();

    /// @dev Revert with `GracePeriodNotOver` if the grace period after sequencer restart is not over.
    error GracePeriodNotOver();

    /// @dev Revert with `StalePriceData` if the price data is stale.
    error StalePriceData();

    /// @dev Revert with `InvalidPriceData` if the price data is invalid.
    error InvalidPriceData();

    /// @dev Revert with `AlreadyPaid` if the user has already made a payment.
    error AlreadyPaid();

    /*//////////////////////////////////////////////////////////////
                                        EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a payment is received.
     *
     * @param payer The address of the payer.
     * @param amount The amount paid.
     * @param paymentMethod The method of payment ("USDC", "DAI", "USDT", or "ETH").
     */
    event PaymentReceived(
        address indexed payer,
        uint256 amount,
        string paymentMethod
    );

    event PaymentAmountUpdated(uint256 newAmount);
    event USDCTokenUpdated(address newTokenAddress);
    event DAITokenUpdated(address newTokenAddress);
    event USDTTokenUpdated(address newTokenAddress);
    event PriceFeedUpdated(address newPriceFeedAddress);
    event SequencerUptimeFeedUpdated(address newSequencerFeedAddress);

    /*//////////////////////////////////////////////////////////////
                                      FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initialize the contract with required parameters.
     * @param _owner The owner of the contract.
     * @param _usdcTokenAddress The address of the USDC token contract.
     * @param _daiTokenAddress The address of the DAI token contract.
     * @param _usdtTokenAddress The address of the USDT token contract.
     * @param _priceFeedAddress The address of the Chainlink ETH/USD price feed.
     * @param _sequencerUptimeFeed The address of the Chainlink Sequencer Uptime Feed.
     */
    function initialize(
        address _owner,
        address _usdcTokenAddress, // 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
        address _daiTokenAddress, // 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb
        address _usdtTokenAddress, // 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2
        address _priceFeedAddress, // 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70
        address _sequencerUptimeFeed // 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433
    ) public initializer {
        if (_owner == address(0)) revert InvalidAddress();
        if (_usdcTokenAddress == address(0)) revert InvalidAddress();
        if (_daiTokenAddress == address(0)) revert InvalidAddress();
        if (_usdtTokenAddress == address(0)) revert InvalidAddress();
        if (_priceFeedAddress == address(0)) revert InvalidAddress();
        if (_sequencerUptimeFeed == address(0)) revert InvalidAddress();

        __Pausable_init();
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        usdcToken = IERC20(_usdcTokenAddress);
        daiToken = IERC20(_daiTokenAddress);
        usdtToken = IERC20(_usdtTokenAddress);
        priceFeed = AggregatorV2V3Interface(_priceFeedAddress);
        sequencerUptimeFeed = AggregatorV2V3Interface(_sequencerUptimeFeed);

        // Set the payment amount to 10 USD
        paymentAmountUSD = 10;

        // Set the unit factor for USDC, DAI, and USDT
        UNIT_FACTOR_USDC = 10 ** 6;
        UNIT_FACTOR_DAI = 10 ** 18;
        UNIT_FACTOR_USDT = 10 ** 6;

        // Pause the contract initially
        _pause();
    }

    /**
     * @notice Pay 10 USDC to the contract.
     */
    function payWithUSDC() external nonReentrant whenNotPaused {
        if (hasPaid[msg.sender]) {
            revert AlreadyPaid();
        }

        uint256 amount = paymentAmountUSD * UNIT_FACTOR_USDC;

        // Transfer USDC from sender to this contract
        usdcToken.safeTransferFrom(msg.sender, address(this), amount);

        // Mark the sender as having paid
        hasPaid[msg.sender] = true;

        emit PaymentReceived(msg.sender, amount, "USDC");
    }

    /**
     * @notice Pay 10 DAI to the contract.
     */
    function payWithDAI() external nonReentrant whenNotPaused {
        if (hasPaid[msg.sender]) {
            revert AlreadyPaid();
        }

        uint256 amount = paymentAmountUSD * UNIT_FACTOR_DAI;

        // Transfer DAI from sender to this contract
        daiToken.safeTransferFrom(msg.sender, address(this), amount);

        // Mark the sender as having paid
        hasPaid[msg.sender] = true;

        emit PaymentReceived(msg.sender, amount, "DAI");
    }

    /**
     * @notice Pay 10 USDT to the contract.
     */
    function payWithUSDT() external nonReentrant whenNotPaused {
        if (hasPaid[msg.sender]) {
            revert AlreadyPaid();
        }

        uint256 amount = paymentAmountUSD * UNIT_FACTOR_USDT;

        // Transfer USDT from sender to this contract
        usdtToken.safeTransferFrom(msg.sender, address(this), amount);

        // Mark the sender as having paid
        hasPaid[msg.sender] = true;

        emit PaymentReceived(msg.sender, amount, "USDT");
    }

    /**
     * @notice Pay the equivalent of 10 USD in ETH to the contract.
     */
    function payWithETH() external payable nonReentrant whenNotPaused {
        if (hasPaid[msg.sender]) {
            revert AlreadyPaid();
        }

        // Calculate the required ETH amount in wei
        // paymentAmountUSD is in USD (no decimals)
        // ethPriceUSD has 8 decimals, so we adjust by multiplying with 1e26 to get wei units

        uint256 ethPriceUSD = getLatestETHPrice(); // Price with 8 decimals
        uint256 requiredETH = (paymentAmountUSD * 1e26) / ethPriceUSD;

        if (msg.value < requiredETH) {
            revert InsufficientPayment();
        }

        // Mark the sender as having paid
        hasPaid[msg.sender] = true;

        emit PaymentReceived(msg.sender, requiredETH, "ETH");
    }

    /*//////////////////////////////////////////////////////////////
                                    HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the latest ETH price in USD with 8 decimals.
     * @dev Includes checks for sequencer uptime and data freshness.
     * @return price The latest ETH price in USD with 8 decimals.
     */
    function getLatestETHPrice() public view returns (uint256) {
        // prettier-ignore
        (
            /*uint80 roundId*/,
            int256 answer,
            uint256 startedAt,
            /*uint256 updatedAt*/,
            /*uint80 answeredInRound*/
        ) = sequencerUptimeFeed.latestRoundData();

        // // Answer == 0: Sequencer is up
        // // Answer == 1: Sequencer is down
        bool isSequencerUp = answer == 0;
        if (!isSequencerUp) {
            revert SequencerDown();
        }

        // // Ensure the grace period has passed after sequencer restarts
        uint256 timeSinceUp = block.timestamp - startedAt;
        if (timeSinceUp <= GRACE_PERIOD_TIME) {
            revert GracePeriodNotOver();
        }

        // Fetch the latest ETH price
        (
            ,
            /* uint80 roundID */ int256 price,
            ,
            /* uint256 startedAt */ uint256 updatedAt /* uint80 answeredInRound */,

        ) = priceFeed.latestRoundData();

        if (price <= 0) {
            revert InvalidPriceData();
        }

        // Check if the price data is stale (updated within the last hour)
        uint256 timeSinceUpdate = block.timestamp - updatedAt;
        if (timeSinceUpdate > 1 hours) {
            revert StalePriceData();
        }

        return uint256(price); // Price with 8 decimals
    }

    /**
     * @notice Returns the amount of ETH required to pay 10 USD.
     */
    function getRequiredETHAmount() external view returns (uint256) {
        uint256 ethPriceUSD = getLatestETHPrice(); // Price with 8 decimals
        // Multiply paymentAmountUSD by 1e26 to adjust for decimals
        return (paymentAmountUSD * 1e26) / ethPriceUSD;
    }

    /**
     * @notice Returns the amount of ETH required to pay 10 usd with a 5% buffer.
     */
    function getRequiredETHAmountWithBuffer() external view returns (uint256) {
        uint256 ethPriceUSD = getLatestETHPrice(); // Price with 8 decimals
        uint256 requiredETH = (paymentAmountUSD * 1e26) / ethPriceUSD;
        return (requiredETH * 105) / 100; // Add 5% buffer
    }

    /*//////////////////////////////////////////////////////////////
                                   ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the payment amount in USD.
     * @param amount The new payment amount in USD.  (e.g., for $10, amount = 10).
     */
    function setPaymentAmountUSD(uint256 amount) external onlyOwner {
        paymentAmountUSD = amount;
        emit PaymentAmountUpdated(amount);
    }

    /**
     * @notice Set unit factor for USDC.
     * @param decimals The number of decimals for USDC.
     */
    function setUnitFactorUSDC(uint256 decimals) external onlyOwner {
        UNIT_FACTOR_USDC = 10 ** decimals;
    }

    /**
     * @notice Set unit factor for DAI.
     * @param decimals The number of decimals for DAI.
     */
    function setUnitFactorDAI(uint256 decimals) external onlyOwner {
        UNIT_FACTOR_DAI = 10 ** decimals;
    }

    /**
     * @notice Set decimals for USDT
     * @param decimals The number of decimals for USDT.
     */
    function setUnitFactorUSDT(uint256 decimals) external onlyOwner {
        UNIT_FACTOR_USDT = 10 ** decimals;
    }

    /**
     * @notice Set the USDC token contract address.
     * @param _usdcTokenAddress The address of the new USDC token contract.
     */
    function setUSDCToken(address _usdcTokenAddress) external onlyOwner {
        if (_usdcTokenAddress == address(0)) revert InvalidAddress();
        usdcToken = IERC20(_usdcTokenAddress);
        emit USDCTokenUpdated(_usdcTokenAddress);
    }

    /**
     * @notice Set the DAI token contract address.
     * @param _daiTokenAddress The address of the new DAI token contract.
     */
    function setDAIToken(address _daiTokenAddress) external onlyOwner {
        if (_daiTokenAddress == address(0)) revert InvalidAddress();
        daiToken = IERC20(_daiTokenAddress);
        emit DAITokenUpdated(_daiTokenAddress);
    }

    /**
     * @notice Set the USDT token contract address.
     * @param _usdtTokenAddress The address of the new USDT token contract.
     */
    function setUSDTToken(address _usdtTokenAddress) external onlyOwner {
        if (_usdtTokenAddress == address(0)) revert InvalidAddress();
        usdtToken = IERC20(_usdtTokenAddress);
        emit USDTTokenUpdated(_usdtTokenAddress);
    }

    /**
     * @notice Set the Chainlink ETH/USD price feed address.
     * @param _priceFeedAddress The address of the new price feed.
     */
    function setPriceFeed(address _priceFeedAddress) external onlyOwner {
        if (_priceFeedAddress == address(0)) revert InvalidAddress();
        priceFeed = AggregatorV2V3Interface(_priceFeedAddress);
        emit PriceFeedUpdated(_priceFeedAddress);
    }

    /**
     * @notice Set the Chainlink Sequencer Uptime Feed address.
     * @param _sequencerUptimeFeed The address of the new sequencer uptime feed.
     */
    function setSequencerUptimeFeed(
        address _sequencerUptimeFeed
    ) external onlyOwner {
        if (_sequencerUptimeFeed == address(0)) revert InvalidAddress();
        sequencerUptimeFeed = AggregatorV2V3Interface(_sequencerUptimeFeed);
        emit SequencerUptimeFeedUpdated(_sequencerUptimeFeed);
    }

    /**
     * @notice Withdraw all ETH from the contract to a specified address.
     * @param recipient The address to receive the ETH.
     */
    function withdrawETH(address payable recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        uint256 balance = address(this).balance;
        (bool success, ) = recipient.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @notice Withdraw all USDC from the contract to a specified address.
     * @param recipient The address to receive the USDC.
     */
    function withdrawUSDC(address recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        uint256 balance = usdcToken.balanceOf(address(this));
        usdcToken.safeTransfer(recipient, balance);
    }

    /**
     * @notice Withdraw all DAI from the contract to a specified address.
     * @param recipient The address to receive the DAI.
     */
    function withdrawDAI(address recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        uint256 balance = daiToken.balanceOf(address(this));
        daiToken.safeTransfer(recipient, balance);
    }

    /**
     * @notice Withdraw all USDT from the contract to a specified address.
     * @param recipient The address to receive the USDT.
     */
    function withdrawUSDT(address recipient) external onlyOwner {
        if (recipient == address(0)) revert InvalidAddress();
        uint256 balance = usdtToken.balanceOf(address(this));
        usdtToken.safeTransfer(recipient, balance);
    }

    /**
     * @notice Pause the contract.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Authorize contract upgrades.
     * @param newImplementation The address of the new contract implementation.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                                PAYMENT STATUS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Check if an address has paid.
     * @param user The address to check.
     * @return True if the user has paid, false otherwise.
     */
    function checkPaymentStatus(address user) external view returns (bool) {
        return hasPaid[user];
    }

    /**
     * @notice Reset the payment status for a user.
     * @param user The address to reset.
     */
    function resetPaymentStatus(address user) external onlyOwner {
        hasPaid[user] = false;
    }
}
