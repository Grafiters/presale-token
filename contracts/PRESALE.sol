// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/**
 * @title Interface ERC20 (IERC20)
 */
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


/**
 * @title SafeERC20 (Menghindari kesalahan transfer token)
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        require(token.transfer(to, amount), "SafeERC20: Transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 amount) internal {
        require(token.transferFrom(from, to, amount), "SafeERC20: TransferFrom failed");
    }
}

/**
 * @title Ownable (Hanya Owner yang bisa akses fungsi tertentu)
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: Caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: New owner is the zero address");
        _owner = newOwner;
        emit OwnershipTransferred(msg.sender, newOwner);
    }
}

/**
 * @title Launchpad DEX (Standalone)
 */

contract LaunchpadDEX {
    using SafeERC20 for IERC20;

    struct Presale {
        address creator;
        address token;
        address paymentToken;
        uint256 rate;
        uint256 startTime;
        uint256 endTime;
        uint256 amountSold;
        uint256 hardCap;
        uint256 totalRaised;
        uint256 totalClaimed;
        bool completed;
    }

    mapping(address => Presale) public presales;
    address[] public projects;

    event PresaleCreated(address indexed creator, address indexed token, uint256 rate, uint256 startTime, uint256 endTime);
    event TokenPurchased(address indexed buyer, uint256 amount);
    event TokensClaimed(address indexed claimer, uint256 amount);
    event FundsWithdrawn(address indexed creator, uint256 amount);
    event UnsoldTokensWithdrawn(address indexed creator, uint256 amount);
    event PresaleEnded(address indexed token);

    modifier presaleExists(address _token) {
        require(presales[_token].token != address(0), "Presale does not exist");
        _;
    }

    modifier onlyCreator(address _token) {
        require(presales[_token].creator == msg.sender, "Only presale creator can perform this action");
        _;
    }

    modifier onlyActivePresale(address _token) {
        Presale storage presale = presales[_token];
        require(block.timestamp >= presale.startTime, "Presale not started");
        require(block.timestamp <= presale.endTime, "Presale ended");
        _;
    }

    function createPresale(
        address _token, 
        address _paymentToken, 
        uint256 _rate, 
        uint256 _startTime, 
        uint256 _endTime, 
        uint256 _hardCap
    ) external {
        require(_endTime > _startTime, "End time must be after start time");
        require(presales[_token].token == address(0), "Presale already exists");

        presales[_token] = Presale({
            creator: msg.sender,
            token: _token,
            paymentToken: _paymentToken,
            rate: _rate,
            startTime: _startTime,
            endTime: _endTime,
            amountSold: 0,
            hardCap: _hardCap,
            totalRaised: 0,
            totalClaimed: 0,
            completed: false
        });

        projects.push(_token);
        emit PresaleCreated(msg.sender, _token, _rate, _startTime, _endTime);
    }

    function buyToken(address _token, uint256 _amount) 
        external 
        presaleExists(_token) 
        onlyActivePresale(_token) 
    {
        Presale storage presale = presales[_token];
        require(presale.amountSold + _amount <= presale.hardCap, "Hard cap reached");

        uint256 tokensToBuy = _amount * presale.rate;

        IERC20(presale.paymentToken).safeTransferFrom(msg.sender, address(this), _amount);

        presale.amountSold += _amount;
        presale.totalRaised += _amount;

        emit TokenPurchased(msg.sender, tokensToBuy);
    }

    function claimTokens(address _token) 
        external 
        presaleExists(_token) 
    {
        Presale storage presale = presales[_token];
        require(block.timestamp > presale.endTime, "Presale not ended");
        require(presale.completed, "Creator has not ended presale");

        uint256 amount = presale.amountSold;
        require(amount > 0, "No tokens to claim");

        presale.totalClaimed += amount;

        IERC20(_token).safeTransfer(msg.sender, amount);

        emit TokensClaimed(msg.sender, amount);
    }

    function endPresale(address _token) 
        external 
        onlyCreator(_token) 
        presaleExists(_token) 
    {
        Presale storage presale = presales[_token];
        require(block.timestamp > presale.endTime, "Presale not ended yet");
        require(!presale.completed, "Presale already ended");

        presale.completed = true;

        emit PresaleEnded(_token);
    }

    function withdrawFunds(address _token) 
        external 
        onlyCreator(_token) 
        presaleExists(_token) 
    {
        Presale storage presale = presales[_token];
        require(presale.completed, "Presale must be ended first");

        uint256 amount = presale.totalRaised;
        require(amount > 0, "No funds to withdraw");

        presale.totalRaised = 0;
        IERC20(presale.paymentToken).safeTransfer(msg.sender, amount);

        emit FundsWithdrawn(msg.sender, amount);
    }

    function withdrawUnsoldTokens(address _token)
        external 
        onlyCreator(_token) 
        presaleExists(_token) 
    {
        Presale storage presale = presales[_token];
        require(presale.completed, "Presale must be ended first");

        uint256 unsoldTokens = (presale.hardCap * presale.rate) - presale.totalClaimed;
        require(unsoldTokens > 0, "No unsold tokens");

        IERC20(_token).safeTransfer(msg.sender, unsoldTokens);

        emit UnsoldTokensWithdrawn(msg.sender, unsoldTokens);
    }

    function getPresale(uint256 tokenId) external view returns (Presale memory) {
        uint256 length = projects.length;
        Presale[] memory allPresales = new Presale[](length);
        return allPresales[tokenId];
    }

    function getAmountRate(address _token, uint256 _amount) external view returns (uint256) {
        uint256 tokensToBuy = _amount * presales[_token].rate;
        return tokensToBuy;
    }

    function getLength() external view returns (uint256) {
        return projects.length;
    }

    function getTotalClaimed(address _token) external view returns (uint256) {
        return presales[_token].totalClaimed;
    }

    function getTotalRaised(address _token) external view returns (uint256) {
        return presales[_token].totalRaised;
    }

    /**
     * @dev Mengembalikan semua data presale yang telah dibuat.
     */
    function getAllPresales() external view returns (Presale[] memory) {
        uint256 length = projects.length;
        Presale[] memory allPresales = new Presale[](length);

        for (uint256 i = 0; i < length; i++) {
            allPresales[i] = presales[projects[i]];
        }

        return allPresales;
    }
}