//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./libraries/LibDiamond.sol";
import "./interfaces/IDiamondLoupe.sol";
import "./interfaces/IDiamondCut.sol";
import "./libraries/AppStorage.sol";
import "./facets/LeaseERC721Facet.sol";



contract LeaseDiamond {
    AppStorage s;
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);

    struct ConstructorArgs {
        address owner;
        string name;
        string symbol;
        uint256 rentPrice;
        uint256 baseRentTime;        
    }



    constructor(IDiamondCut.FacetCut[] memory _diamondCut, ConstructorArgs memory _args) {
        require(_args.owner != address(0), "LeaseDiamond: owner can't be address(0)");        
        LibDiamond.diamondCut(_diamondCut, address(0), new bytes(0));
        LibDiamond.setContractOwner(_args.owner);

        // initialize state for NFT
        s.erc721f._name = _args.name;
        s.erc721f._symbol = _args.symbol;
        s.erc721f.rentPrice = _args.rentPrice;
        s.erc721f.baseRentTime = _args.baseRentTime;


        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();



       
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;        
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;

        

        // // create wearable tickets:
        // emit TransferSingle(msg.sender, address(0), address(0), 0, 0);
        // emit TransferSingle(msg.sender, address(0), address(0), 1, 0);
        // emit TransferSingle(msg.sender, address(0), address(0), 2, 0);
        // emit TransferSingle(msg.sender, address(0), address(0), 3, 0);
        // emit TransferSingle(msg.sender, address(0), address(0), 4, 0);
        // emit TransferSingle(msg.sender, address(0), address(0), 5, 0);
    }

    // Find facet for function that is called and execute the
    // function if a facet is found and return any value.
    fallback() external payable {
        LibDiamond.DiamondStorage storage ds;
        bytes32 position = LibDiamond.DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
        address facet = address(bytes20(ds.facets[msg.sig]));
        require(facet != address(0), "LeaseDiamond: Function does not exist");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
                case 0 {
                    revert(0, returndatasize())
                }
                default {
                    return(0, returndatasize())
                }
        }
    }

    receive() external payable {
        revert("LeaseDiamond: Does not accept ether");
    }
}


