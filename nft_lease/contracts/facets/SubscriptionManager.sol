pragma solidity ^0.8.0;

import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "./LeaseERC721Facet.sol";



contract SubscriptionManager {
    AppStorage internal s;

    event RentExtendedWithRewards(uint256 blocksExtended, uint256 tokenId);


    // sets the reward token
    function setClubToken(address _tokenAddress) external {
        LibDiamond.enforceIsContractOwner();
        s.subMan.clubToken = ClubToken(_tokenAddress);
        s.subMan.tokenSet = true;
    }


    // allows contract owner to set a reward amount
    function setRewardAmount(uint256 _newRewardAmount) external {
        LibDiamond.enforceIsContractOwner();
        s.subMan.rewardAmount = _newRewardAmount;
    }


    // allows contract owner to set a conversion ratio form club token to one unit of rent
    function setTokenConversionRation(uint256 _conversionRatio) external {
        LibDiamond.enforceIsContractOwner();
        s.subMan.conversionRatio = _conversionRatio;
    }

    // sets amount of time required between updating user status
    function setBlocksBetweenUpdate(uint256 _blocksBetweenUpdate) external {
        LibDiamond.enforceIsContractOwner();
        s.subMan.blocksBetweenUpdate = _blocksBetweenUpdate;
    }


    // pays users in erc20 based on subscription model 
    // if rent not paid, reclaims NFT
    // owner should call this function at the begging of each subscription period
    function updateUsersStatus() external {
        LibDiamond.enforceIsContractOwner();
        require(s.subMan.lastBlockUpdate + s.subMan.blocksBetweenUpdate <= block.number, "SubscriptionManager: not enough blocks have passed since last update");
        require(s.subMan.tokenSet == true, "SubscriptionManager: contract owner must set reward token");
        require(s.subMan.rewardAmount != 0, "SubscriptionManager: contract owner has not set a reward amount");
        
        s.subMan.lastBlockUpdate = block.number;
        LeaseERC721Facet subscribtionToken = LeaseERC721Facet(address(this));
        ClubToken clubToken = s.subMan.clubToken;
        uint256 rewardAmount = s.subMan.rewardAmount;

        uint256 circSupply = s.erc721f.circulatingSupply;
        uint256 i = 1;

        for (i; i <= circSupply; ++i) {
            if(subscribtionToken.getRentedBlocksRemaining(i) > 0) {
                clubToken.mint(s.erc721f._owners[i], rewardAmount);
            } else {
                subscribtionToken.reclaim(i);
            }
        }
    }

    // allows users to redeem erc20 for rent on subscription nft
    function redeemRentWithRewards(uint256 _redeemAmount, uint256 _tokenId) external {
        uint256 conversionRatio = s.subMan.conversionRatio;
        ClubToken clubToken = s.subMan.clubToken;
        require(s.subMan.tokenSet == true, "SubscriptionManager: contract owner must set reward token");
        require(conversionRatio != 0, "SubscriptionManager: contract owner has not set a reward conversion yet");
        require(_redeemAmount >= conversionRatio, "SubscriptionManager: _redeemAmount must be greater than if not equal to the conversionRatio");
        require(clubToken.allowance(msg.sender, address(this)) >= _redeemAmount, "SubscriptionManager: user has not approved enough club tokens");

        clubToken.transferFrom(msg.sender, address(this), _redeemAmount);
        
        uint256 rentAmount = s.erc721f.baseRentTime * (_redeemAmount / conversionRatio);

        LeaseERC721Facet subscribtionToken = LeaseERC721Facet(address(this));
        subscribtionToken.ownerAllowedRent(_tokenId, rentAmount);
    }


    

}