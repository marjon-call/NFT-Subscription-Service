pragma solidity ^0.8.0;

import "../libraries/AppStorage.sol";
import "../libraries/LibDiamond.sol";
import "hardhat/console.sol";


// look into removing this
interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}






contract LeaseERC721Facet  {
    AppStorage internal s;
    

    event Transfer(address from, address to, uint256 tokenId);
    event Approval(address owner, address approved, uint256 tokenId);
    event ApprovalForAll(address owner, address operator, bool approved);
    event RentPaid(uint256 tokenId, uint256 rentPaid);
    event ReclaimToken(uint256 tokenId);
    event Repurchase(uint256 tokenId, uint256 rentPaid);



    // sets price per time period
    function setRentPrice(uint256 _price) external {
        LibDiamond.enforceIsContractOwner();
        s.erc721f.rentPrice = _price;
    }


    // sets the amount of blocks that you rent with one unit of rent
    function setBaseRentTime(uint256 _blocks) external {
        LibDiamond.enforceIsContractOwner();
        s.erc721f.baseRentTime = _blocks;
    }

    // checks how many blocks until subscription expires
    function getRentedBlocksRemaining(uint256 _tokenId) public view returns (uint256) {
        require(_exists(_tokenId), "LeaseERC721Facet: invalid token ID");
        // uint256 userRentBalance = s.erc721f.rentBalance[_tokenId];
        // uint256 userBlockRentPayed = s.erc721f.blockRentPayed[_tokenId];

        if(block.number - s.erc721f.blockRentPayed[_tokenId] >= s.erc721f.rentBalance[_tokenId]) {
            return 0;
        } else {
            return s.erc721f.rentBalance[_tokenId] - (block.number - s.erc721f.blockRentPayed[_tokenId]);
        }

    }

    // updates rent depending on cost. 
    // Send full units of rent to avoid wasting ether!
    function payRent(uint256 _tokenId) external payable {
        uint256 rentPrice = s.erc721f.rentPrice;
        require(_exists(_tokenId), "LeaseERC721Facet: invalid token ID"); 
        require(msg.value >= rentPrice, "LeaseERC721Facet: not enough rent sent to contract");

        uint256 currRentBalance = getRentedBlocksRemaining(_tokenId) + (s.erc721f.baseRentTime * (msg.value / rentPrice));

        s.erc721f.rentBalance[_tokenId] = currRentBalance;
        s.erc721f.blockRentPayed[_tokenId] = block.number;

        emit RentPaid(_tokenId, currRentBalance);
    }


    // allows owner to pay rent for user
    // used in SubscriptionManager to redeem ClubToken for rent
    function ownerAllowedRent(uint256 _tokenId, uint256 _rentAdded) external {
        require(msg.sender == LibDiamond.contractOwner() || msg.sender == address(this), "LeaseERC721Facet: unauthorized contract call");
        require(_exists(_tokenId), "LeaseERC721Facet: invalid token ID");

        uint256 currRentBalance = getRentedBlocksRemaining(_tokenId) + _rentAdded;

        s.erc721f.rentBalance[_tokenId] = currRentBalance;
        s.erc721f.blockRentPayed[_tokenId] = block.number;

        emit RentPaid(_tokenId, currRentBalance);
    }

    // reclaim a single nft that has not paid their rent
    function reclaim(uint256 _tokenId) external {
        require(msg.sender == LibDiamond.contractOwner() || (msg.sender == address(this) && tx.origin == LibDiamond.contractOwner()), "LeaseERC721Facet: unauthorized contract call");
        require(_exists(_tokenId), "LeaseERC721Facet: invalid token ID"); 
        require(getRentedBlocksRemaining(_tokenId) == 0, "LeaseERC721Facet: user has paid rent for this block");

        delete s.erc721f._tokenApprovals[_tokenId];

        s.erc721f.reclaimedPrevAddress[_tokenId] = s.erc721f._owners[_tokenId];
        s.erc721f._balances[s.erc721f._owners[_tokenId]] -= 1;
        s.erc721f._balances[address(this)] += 1;
        s.erc721f._owners[_tokenId] = address(this);

        emit ReclaimToken(_tokenId);

    }

    // reclaims multiple nfts that have not paid there rent
    function reclaimBatch(uint256[] calldata _tokenIds) external {
        LibDiamond.enforceIsContractOwner();

        uint256 batchLength = _tokenIds.length;
        uint256 i;

        for(i; i < batchLength; ++i) {
            if (getRentedBlocksRemaining(_tokenIds[i]) == 0 && _exists(_tokenIds[i])) {
                
                delete s.erc721f._tokenApprovals[_tokenIds[i]];

                s.erc721f.reclaimedPrevAddress[_tokenIds[i]] = s.erc721f._owners[_tokenIds[i]];
                s.erc721f._balances[s.erc721f._owners[_tokenIds[i]]] -= 1;
                
                s.erc721f._balances[address(this)] += 1;
                s.erc721f._owners[_tokenIds[i]] = address(this);

                emit ReclaimToken(_tokenIds[i]);
            }
        }
    }

    // repurchase nft that has been reclamied
    // Send full units of rent to avoid wasting ether!
    function repurchase(uint256 _tokenId) external payable {
        uint256 rentPrice = s.erc721f.rentPrice;
        require(_exists(_tokenId), "LeaseERC721Facet: invalid token ID"); 
        require(s.erc721f.reclaimedPrevAddress[_tokenId] == msg.sender, "LeaseERC721Factet: user was not the previous owner of token");
        require(msg.value >= rentPrice, "LeaseERC721Facet: not enough rent sent to contract");

        delete s.erc721f.reclaimedPrevAddress[_tokenId];
        _transfer(address(this), msg.sender, _tokenId);

        uint256 currRentBalance = (s.erc721f.baseRentTime * (msg.value / rentPrice));

        s.erc721f.rentBalance[_tokenId] = currRentBalance;
        s.erc721f.blockRentPayed[_tokenId] = block.number;

        emit Repurchase(_tokenId, currRentBalance);
    }


    function name() external view returns (string memory) {
        return s.erc721f._name ;
    }
   
    function symbol() external view returns (string memory) {
        return s.erc721f._symbol;
    }

    function circulatingSupply() external view returns(uint256) {
        return s.erc721f.circulatingSupply;
    }


    function balanceOf(address owner) external view  returns (uint256) {
        require(owner != address(0), "LeaseERC721Facet: address zero is not a valid owner");
        return s.erc721f._balances[owner];
    }

    
    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = s.erc721f._owners[tokenId];
        require(owner != address(0), "LeaseERC721Facet: invalid token ID");
        return owner;
    }


    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }


    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(msg.sender, tokenId), "LeaseERC721Facet: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }


    function approve(address to, uint256 tokenId) public virtual {
        address owner = ownerOf(tokenId);
        require(to != owner, "LeaseERC721Facet: approval to current owner");

        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "LeaseERC721Facet: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    


    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireMinted(tokenId);

        return s.erc721f._tokenApprovals[tokenId];
    }


    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "LeaseERC721Facet: approve to caller");
        s.erc721f._operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }


    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return s.erc721f._operatorApprovals[owner][operator];
    }


    function _approve(address to, uint256 tokenId) internal virtual {
        s.erc721f._tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }


    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "LeaseERC721Facet: invalid token ID");
    }


    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return s.erc721f._owners[tokenId] != address(0);
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual {
        require(_isApprovedOrOwner(msg.sender, tokenId), "LeaseERC721Facet: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }


    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("LeaseERC721Facet: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }


    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "LeaseERC721Facet: transfer to non ERC721Receiver implementer");
    }


    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ownerOf(tokenId) == from, "LeaseERC721Facet: transfer from incorrect owner");
        require(to != address(0), "LeaseERC721Facet: transfer to the zero address");


        // Clear approvals from the previous owner
        delete s.erc721f._tokenApprovals[tokenId];

        s.erc721f._balances[from] -= 1;
        s.erc721f._balances[to] += 1;
        s.erc721f._owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }


    

    // mints token
    // Send full units of rent to avoid wasting ether!
    function mint(address to) external payable  {    
        uint256 rentPrice = s.erc721f.rentPrice;  
        require(to != address(0), "LeaseERC721Facet: mint to the zero address");
        require(msg.value >= rentPrice, "LeaseERC721Facet: not enough rent sent to contract");


        s.erc721f.circulatingSupply++;
        uint256 tokenId = s.erc721f.circulatingSupply;
        s.erc721f._balances[to] += 1;
        s.erc721f._owners[tokenId] = to;

        s.erc721f.rentBalance[tokenId] = s.erc721f.baseRentTime * (msg.value / rentPrice);
        s.erc721f.blockRentPayed[tokenId] = block.number;

        emit Transfer(address(0), to, tokenId);

    }

    
    
}