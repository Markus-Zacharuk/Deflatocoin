// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/master/contracts/token/ERC20/IERC20.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/master/contracts/GSN/Context.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/master/contracts/math/SafeMath.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v3.3.0/master/contracts/utils/ReentrancyGuard.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DeflatoCoin is Context, IERC20, ReentrancyGuard {
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;

  uint256 _totalSupply;
  string _name;
  string _symbol;
  uint8 _decimals;
  uint256 _releaseTime;
  address _admin;

  event TokenSaleTransfer(address indexed buyer, uint256 amount);
  event RedeemEther(address indexed redeemer, uint256 amount);

  constructor (string memory name_, string memory symbol_, uint256 saleInDays_) ReentrancyGuard() {
    require (saleInDays_ > 0, "Release time is not positive.");
    _name = name_;
    _symbol = symbol_;
    _decimals = 18;
    _releaseTime = block.timestamp + saleInDays_ * 1 days;
    _admin = msg.sender;
  }

  function name() public view returns (string memory) {
    return _name;
  }

  function symbol() public view returns (string memory) {
    return _symbol;
  }

  function decimals() public view returns (uint8) {
    return _decimals;
  }

  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function releaseTime() public view returns (uint256) {
    return _releaseTime;
  }

  function timeUntilRelease() public view returns (uint256) {
    require(saleIsActive());
    return _releaseTime.sub(block.timestamp, "Function called after release happend");
  }

  function saleIsActive() public view returns (bool) {
    return block.timestamp < _releaseTime;
  }

  function transfer(address recipient, uint256 amount) public override returns (bool) {
    _transfer(_msgSender(), recipient, amount);    
    return true;
  }

  function allowance(address owner, address spender) public view override returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) public override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
      _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
      return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
      _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
      return true;
  }

  function buyFromTokenSale() public payable returns (bool) {
    require(block.timestamp < _releaseTime, "Can't buy from token sale after end of token sale.");
    require(msg.sender != address(0), "ERC20: transfer to the zero address");
    require(msg.value > 0, "Refused to sell zero tokens.");
    _balances[msg.sender] = _balances[msg.sender].add(msg.value, "Error while increasing token balance");
    _totalSupply = _totalSupply.add(msg.value, "Error while increasing total supply");
    emit TokenSaleTransfer(_msgSender(), msg.value);
    return true;
  }

  function redeemEther(uint256 amount) nonReentrant() public {
    require(block.timestamp >= _releaseTime, "Can't redeem Ether before end of token sale");
    require(msg.sender == _admin, "Only the admin can redeem ether");
    require (amount <= address(this).balance, "Can't redeem more than the actual balance");
    msg.sender.transfer(amount);
    emit RedeemEther(msg.sender, amount);
  }

  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "ERC20: transfer from the zero address");
    require(recipient != address(0), "ERC20: transfer to the zero address");
    // If you could send 0 tokens,  you could drain someones wallet by repeated sending this.
    require(amount > 0);
    // Added this, so tokens are locked until end of token sale.
    require(block.timestamp >= _releaseTime, "Can't transfer Tokens before end of token sale.");
    // txFee is the amount, the receiver will burn (about 1%).
    uint256 txFee;
    if (amount <= 100) {
      txFee = 1;
    } else {
      txFee = amount.div(100);
    }
    _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
    // Receipient receives amount - txFee in tokens.
    _balances[recipient] = _balances[recipient].add(amount).sub(txFee, "ERC20: burn amount exceeds balance (1% fee)");
    _totalSupply = _totalSupply.sub(txFee);
    emit Transfer(sender, recipient, amount);
    // Emiting the "burn"-event (Transfer to zero-address).
    emit Transfer(recipient, address(0), txFee);
  }

  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "ERC20: approve from the zero address");
    require(spender != address(0), "ERC20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }
}
