// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ClubToken.sol";

struct ERC721F {
    mapping(uint256 => address) _owners;
    mapping(address => uint256) _balances;
    mapping(uint256 => address) _tokenApprovals;
    mapping(uint256 => uint256) blockRentPayed;
    mapping(uint256 => uint256) rentBalance;
    mapping(uint256 => address) reclaimedPrevAddress;
    mapping(address => mapping(address => bool)) _operatorApprovals;
    string _name;
    string _symbol;
    uint256 circulatingSupply;
    uint256 rentPrice;
    uint256 baseRentTime;
    uint256 baseMintFee;
}

struct SubManage {
    ClubToken clubToken;
    uint256 rewardAmount;
    uint256 conversionRatio;
    uint256 blocksBetweenUpdate;
    uint256 lastBlockUpdate;
    bool tokenSet;
}

struct AppStorage {
    ERC721F erc721f;
    SubManage subMan;
}