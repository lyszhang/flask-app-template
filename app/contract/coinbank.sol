pragma solidity ^ 0.4.24;

contract ERC20Token {
    /* This is a slight change to the ERC20 base standard.
    function totalSupply() constant returns (uint256 supply);
    is replaced with:
    uint256 public totalSupply;
    This automatically creates a getter function for the totalSupply.
    This is moved to the base contract since public getter functions are not
    currently recognised as an implementation of the matching abstract
    function by the compiler.
    */
    /// total amount of tokens
    uint256 public totalSupply;

    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) public view returns (uint256 balance);

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) public returns (bool success);

    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    /// @notice `msg.sender` approves `_spender` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of tokens to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) public returns (bool success);

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);


    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

library SafeMath {
  //@dev Multiplies two numbers, throws on overflow.
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  //@dev Integer division of two numbers, truncating the quotient.
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  //@dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  //@dev Adds two numbers, throws on overflow.
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Owned {
    /// 'owner' is the only address that can call a function with
    /// this modifier
    address public owner;
    address internal newOwner;

    ///@notice The constructor assigns the message sender to be 'owner'
    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    event updateOwner(address _oldOwner, address _newOwner);

    ///change the owner
    function changeOwner(address _newOwner) public onlyOwner returns(bool) {
        require(owner != _newOwner);
        newOwner = _newOwner;
        return true;
    }

    /// accept the ownership
    function acceptNewOwner() public returns(bool) {
        require(msg.sender == newOwner);
        emit updateOwner(owner, newOwner);
        owner = newOwner;
        return true;
    }
}

contract bankStorage is Owned {
    using SafeMath for uint256;

    uint256 public investLowerLimit = 10000000000000000;       //0.01 ether
    uint256 public oneMonth = 2592000;                         //3600*24*30
    uint256 public fortyDay = 3456000;                         //3600*24*40

    //@notice BHQ contract address
    address public BHQaddress = 0x601ad5928e3B0cfD9f1f1C25AdC551cC9828Fb46;
    uint256 public BHQdecimal = 6;

    uint256 public interest = 10;
    uint256 public hundred = 100;

     //@dev for investment's info
    struct investInfo {
        bool paid;
        uint256 time;
        address depositAddr;
        uint256 value;
    }

    mapping (uint256 => investInfo) public investList;
    uint256 investorNum = 0;
    uint256 paidFlag = 0;

    //@dev referee's info
    struct refereeInfo {
        address referee;
    }

    mapping (address => refereeInfo) public refereeList;

    //@dev change invest parameters
    function changeInvestParameter(uint256 _investLowerLimits, uint256 _interest)
        onlyOwner
        public {
            investLowerLimit = _investLowerLimits;
            interest = _interest;
    }

    //@dev deposit the fund
    function depositFunds(uint256 _value)
        onlyOwner
        public {
            require(address(this).balance >= _value);
            owner.transfer(_value);
    }
}

contract coinBank is bankStorage{
    modifier inInvestLimit {
        require(msg.value >= investLowerLimit);
        _;
    }

    modifier noReferee {
        require(refereeList[msg.sender].referee == address(0));
        _;
    }

    function withdrawBHQcoin(address _addr, uint256 _value) internal {
        ERC20Token(BHQaddress).transfer(_addr, _value);
        return;
    }

    function handleCashwithdraw() internal {
        for (uint256 i = paidFlag; i < investorNum; i++) {
            uint256 investInternal = now - investList[i].time;
            uint256 investProfit = investList[i].value + investList[i].value/hundred*interest;
            address withdrawAddr = investList[i].depositAddr;

            //@dev if the investment is expired
            if (investInternal >= oneMonth) {
                if(investProfit <= address(this).balance) {
                    withdrawAddr.transfer(investProfit);

                    //@dev if you got referee, will get 1000 extra BHQ coins
                    if(refereeList[withdrawAddr].referee != address(0)) {
                        withdrawBHQcoin(withdrawAddr, 1000);
                    }
                    //@notice withdrawed, change the state
                    investList[i].paid = true;
                    paidFlag ++;
                    continue;

                    //@dev if the investment already expired 40 days
                } else if (investInternal >= fortyDay) {
                    ///TODO: check the return,and complete the function
                    if(refereeList[withdrawAddr].referee != address(0)) {
                        withdrawBHQcoin(withdrawAddr, investProfit*10 + 1000);
                    } else {
                        withdrawBHQcoin(withdrawAddr, investProfit*10);
                    }

                    //@notice withdrawed, change the state
                    investList[i].paid = true;
                    paidFlag ++;
                    continue;
                }

                //@dev must pay the previous investment then do the next
                break;

            }else {
                //@dev the oldest doesn't expire
                break;
            }
        }
        return;
    }

    // @notice deposite eth for an investment
    function fallback()
        inInvestLimit
        public
        payable {
            investList[investorNum].paid = false;
            investList[investorNum].time = block.timestamp;
            investList[investorNum].depositAddr = msg.sender;
            investorNum++;

            handleCashwithdraw();

            return;
    }

    // @notice register
    function Register(address _referee)
        noReferee
        public
        payable {
            address tempAddr = _referee;
            uint256 i = 1;
            while (tempAddr != address(0)) {
                withdrawBHQcoin(tempAddr, 10*i*10**BHQdecimal);

                if (i < 3) {
                    i++;
                }
                tempAddr = refereeList[tempAddr].referee;
            }

            return;
    }
}




