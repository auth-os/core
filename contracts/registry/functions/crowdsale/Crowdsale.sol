pragma solidity ^0.4.23;

library Token {

  struct User {
    Virtual.Wrapper token;
    Virtual.Wrapper self;
    Virtual.Address user;
    function (Virtual.Wrapper memory) pure returns (bool) transfer;
    function (Virtual.Wrapper memory) pure returns (bool) transferFrom;
    function (Virtual.Wrapper memory) pure returns (bool) approve;
  }

}

library Crowdsale {

  struct Purchase {

  }

  struct Token {

  }

  struct Sale {
    Virtual.Wrapper self;
    Virtual.Address admin;
    Virtual.  
  }
}
