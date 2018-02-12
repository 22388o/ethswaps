pragma solidity ^0.4.19;

contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract AtomicTokenSwap {
    struct Swap {
        uint expiration;
        address initiator;
        address participant;
        address token;
        uint256 value;
        bool exists;
    }

    // maps the bytes20 hash to a swap    
    mapping(bytes20 => Swap) private swaps;
    
    // creates a new swap
    function initiate(uint _expiration, bytes20 _hash, address _participant, address _token, uint256 _value) public {
        Swap storage s = swaps[_hash];
        
        // make sure you aren't overwriting a pre-existing swap
        // (so the original initiator can't rewrite the terms)
        require(s.exists == false);

        // require that the sender has allowed the tokens to be withdrawn from their account
        ERC20 token = ERC20(_token);
        require(token.allowance(msg.sender, this) == _value);
        token.transferFrom(msg.sender, this, _value);

        // create the new swap
        swaps[_hash] = Swap(_expiration, msg.sender, _participant, _value, _token, true);
    }
    
    function redeem(bytes32 _secret) public {
        // get a swap from the mapping. we can do it directly because there is no way to 
        // fake the secret.
        bytes20 hash = ripemd160(_secret);
        Swap storage s = swaps[hash];
        
        // make sure it's the right sender
        require(msg.sender == s.participant);
        
        // clean up and send
        s.exists = false;
        ERC20 token = ERC20(s.token);
        token.transferFrom(msg.sender, s.value);
    }
    
    function refund(bytes20 _hash) public {
        Swap storage s = swaps[_hash];
        require(now > s.expiration);
        require(msg.sender == s.initiator);
        
        s.exists = false;
        ERC20 token = ERC20(s.token);
        token.transferFrom(msg.sender, s.value);
    }
}