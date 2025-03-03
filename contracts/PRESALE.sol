// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        require(token.transfer(to, amount), "SafeERC20: Transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        require(token.transferFrom(from, to, amount), "SafeERC20: TransferFrom failed");
    }
}

interface IPancakeRouter {
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable;
}

interface IPancakeFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}


contract PresaleContract {
    using SafeERC20 for IERC20;
    
    address public owner;
    address public creator;

    address public token;
    address public tokenHolder;
    address public wrapped;

    address public router;
    address public factory;
    address public liquidityPair;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public rate;
    uint256 public price;
    uint256 public amountSold;
    uint256 public totalToken;

    uint256 public hardCap;
    uint256 public softCap;
    uint256 public totalRaised;
    uint256 public totalClaimed;

    bool public completed;
    bool public successful;
    mapping(address => uint256) public contributions;

    event TokenPurchased(address indexed buyer, uint256 amount);
    event TokensClaimed(address indexed claimer, uint256 amount);
    event PresaleEnded(bool successful);
    event RefundClaimed(address indexed buyer, uint256 amount);
    event Initialized(address token, uint256 rate, uint256 price, uint256 startTime, uint256 endTime, uint256 totalToken, uint256 hardCap, uint256 softCap);
    event MultiTransferCompleted(address[] recipients, uint256[] amounts);
    event TokensTransferred(address indexed from, address indexed to, uint256 amount);
    event FundsForwarded(address indexed from, address indexed tokenHolder, uint256 amount);
    event LiquidityTransferred(address indexed from, address indexed to, uint256 amount);
    event TokensSwapped(uint256 tokenAmount, uint256 ethReceived);
    event LiquidityAdded(uint256 tokenAmount, uint256 ethAmount, address liquidityPair);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor(address _creator, address _tokenHolder, address _router, address _factory, address _wrapped) {
        owner = msg.sender;
        creator = _creator;
        tokenHolder = _tokenHolder;
        router = _router;
        factory = _factory;
        wrapped = _wrapped;
    }

    function initialize(
        address _token,
        uint256 _rate,
        uint256 _price,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _totalToken,
        uint256 _hardCap,
        uint256 _softCap
    ) external {
        require(_softCap <= _hardCap, "SoftCap must be less than or equal to HardCap");
        require(_token != address(0), "Invalid token address");

        IERC20 erc20 = IERC20(_token);
        uint256 balance = erc20.balanceOf(creator);
        require(balance > totalToken, "Creator does not have enough token balance");

        token = _token;
        rate = _rate;
        price = _price;
        startTime = _startTime;
        endTime = _endTime;
        totalToken = _totalToken;
        hardCap = _hardCap;
        softCap = _softCap;

        liquidityPair = IPancakeFactory(factory).getPair(token, wrapped);

        emit Initialized(_token, _rate, _price, _startTime, _endTime, _totalToken, _hardCap, _softCap);

        // Transfer tokens from creator to the token holder
        erc20.transferFrom(creator, tokenHolder, _totalToken);

        emit TokensTransferred(creator, tokenHolder, _totalToken);
    }

    function calculateTokens(uint256 ethAmount) public view returns (uint256) {
        return (ethAmount * rate) / price;
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    function buyToken() external payable {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Presale not active");
        require(amountSold + msg.value <= hardCap, "Hard cap reached");
        require(msg.value >= price, "Insufficient ETH sent");
        
        uint256 tokensToBuy = calculateTokens(msg.value);
        contributions[msg.sender] += msg.value;
        amountSold += msg.value;
        totalRaised += msg.value;
        
        (bool success, ) = tokenHolder.call{value: msg.value}("");
        require(success, "Transfer to tokenHolder failed");

        emit FundsForwarded(msg.sender, tokenHolder, msg.value);
        emit TokenPurchased(msg.sender, tokensToBuy);
    }

    function claimTokens() external {
        require(block.timestamp > endTime, "Presale not ended yet");
        require(completed, "Presale not finalized");
        require(successful, "Presale did not reach softCap");
        
        uint256 amount = calculateTokens(contributions[msg.sender]);
        require(amount > 0, "No tokens to claim");
        
        contributions[msg.sender] = 0;
        totalClaimed += amount;
        IERC20(token).transferFrom(tokenHolder, msg.sender, amount);
        
        emit TokensClaimed(msg.sender, amount);
    }

    function claimRefund() external {
        require(block.timestamp > endTime, "Presale not ended yet");
        require(completed, "Presale not finalized");
        require(!successful, "Presale reached softCap, no refunds");
        
        uint256 amount = contributions[msg.sender];
        require(amount > 0, "No funds to refund");
        
        contributions[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund transfer failed");
        
        emit RefundClaimed(msg.sender, amount);
    }

    function endPresale() external onlyOwner {
        require(block.timestamp > endTime, "Presale not ended yet");
        require(!completed, "Presale already ended");
        
        completed = true;
        successful = totalRaised >= softCap && totalRaised <= hardCap;

        emit PresaleEnded(successful);
    }

    function multiTransfer(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Invalid input arrays");

        uint256 totalAmount;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        require(IERC20(token).balanceOf(tokenHolder) >= totalAmount, "Insufficient token holder balance");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            IERC20(token).transferFrom(tokenHolder, recipients[i], amounts[i]);
        }
        
        emit MultiTransferCompleted(recipients, amounts);
    }

    function getLiquidityPair() public {
        address pair = IPancakeFactory(factory).getPair(token, wrapped);
        require(pair != address(0), "Liquidity pair does not exist");
        liquidityPair = pair;
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        require(IERC20(token).balanceOf(tokenHolder) >= tokenAmount, "Insufficient token balance");
        require(IERC20(token).transferFrom(tokenHolder, address(this), tokenAmount), "Token transfer failed");

        IERC20(token).approve(router, tokenAmount);

        IPancakeRouter(router).addLiquidityETH{value: ethAmount}(
            token,
            tokenAmount,
            0,
            0,
            liquidityPair,
            block.timestamp + 300
        );

        emit LiquidityAdded(tokenAmount, ethAmount, liquidityPair);
    }
}

contract LaunchpadFactory {
    address public owner;
    address public holder;
    address[] public presaleContracts;
    address public router = 0xd627FfF27633B6704a3eF15F9d66ea24a0eb17Ee;
    address public factory = 0x6a3e838fdf5fB908e76fB7886a22a1c7Ee0f1460;
    address public wrapped = 0xB69Bc23b876daC67e1cE7E20322a12A664f543E6;

    event PresaleCreated(address indexed presaleAddress, address indexed creator);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        holder = msg.sender;
    }

    function createPresale(address _creator) external returns (address) {
        PresaleContract presale = new PresaleContract(
            _creator, holder, router, factory, wrapped
        );
        
        presaleContracts.push(address(presale));
        emit PresaleCreated(address(presale), msg.sender);
        return address(presale);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner");
        owner = _newOwner;
    }

    function transferHoldering(address _newHolder) external onlyOwner {
        require(_newHolder != address(0), "Invalid Holder");
        holder = _newHolder;
    }
}
