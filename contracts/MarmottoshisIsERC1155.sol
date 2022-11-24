// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract MarmottoshisIsERC1155 is ERC1155, ERC2981, Ownable, ReentrancyGuard {

    using Strings for uint;

    struct Artist {
        string name;
        string link;
    }

    enum Step {
        SaleNotStarted,
        WLReservation,
        FreeMint,
        ReservationMint,
        FirstWhitelistMint,
        SecondWhitelistMint,
        PublicMint,
        SoldOut
    }

    Step public currentStep;

    uint public constant maxToken = 21; // 21 different NFTs
    uint public constant maxSupply = 37; // 37 copies of each NFT

    uint public reservationPrice = 0.01 ether; // Price of the reservation

    uint public reservationNFTPrice = 0.008 ether; // Price of the NFT for reservation list
    uint public whitelistPrice = 0.02 ether; // Price of whitelist mint
    uint public publicPrice = 0.03 ether; // Price of public mint

    uint public balanceOfSatoshis = 0; // Balance of Satoshis (100000000 Satoshis = 1 Bitcoin)

    uint public currentReservationNumber = 0; // Current number of reservations purchased

    bytes32 public freeMintMerkleRoot; // Merkle root of the free mint
    bytes32 public firstMerkleRoot; // Merkle root of the first whitelist
    bytes32 public secondMerkleRoot; // Merkle root of the second whitelist

    mapping(uint => Artist) public artistByID; // Artist by ID
    mapping(uint => uint) public supplyByID; // Number of NFTs minted by ID
    mapping(address => bool) public reservationList; // List of addresses that reserved (true = reserved)

    mapping(address => uint) public freeMintByWallet; // Number of NFTs minted by wallet for free mint
    mapping(address => uint) public reservationMintByWallet; // Number of reserved NFT mint by wallet
    mapping(address => uint) public firstWhitelistMintByWallet; // Number of first whitelist NFT mint by wallet
    mapping(address => uint) public secondWhitelistMintByWallet; // Number of second whitelist NFT mint by wallet

    mapping(uint => uint) public balanceOfSatoshiByID; // Balance of Satoshi by token ID

    address public marmott; // Marmott's address

    bool public isMetadataLocked = false; // Locks the metadata URI
    bool public isRevealed = false; // Reveal the NFTs

    event newRedeemRequest(address indexed sender, uint256 nftIdRedeemed, uint256 burnAmount, string btcAddress, uint256 satoshisAmount); // Redeem event
    event newMint(address indexed sender, uint256 nftIdMinted); // Mint event
    event stepUpdated(Step currentStep); // Step update event

    constructor(address _marmott, string memory _uri)
    ERC1155(_uri)
    {
        marmott = _marmott;
    }

    /*
    * @notice Mints a new token to msg.sender
    * @param uint : Id of NFT to mint.
    * @param bytes32[] : Proof of whitelist (could be empty []).
    */
    function mint(uint idToMint, bytes32[] calldata _proof) public payable nonReentrant {
        require(
            currentStep == Step.FreeMint ||
            currentStep == Step.ReservationMint ||
            currentStep == Step.FirstWhitelistMint ||
            currentStep == Step.SecondWhitelistMint ||
            currentStep == Step.PublicMint
        , "Sale is not open");
        require(idToMint >= 1, "Nonexistent id");
        require(idToMint <= maxToken, "Nonexistent id");
        require(supplyByID[idToMint] + 1 <= maxSupply, "Max supply exceeded for this id");

        if (currentStep == Step.FreeMint) {
            require(isOnList(msg.sender, _proof, 0), "Not on free mint list");
            require(totalSupply() + 1 <= 77, "Max free mint supply exceeded");
            require(freeMintByWallet[msg.sender] + 1 <= 1, "You already minted your free NFT");
            freeMintByWallet[msg.sender] += 1;
            _mint(msg.sender, idToMint, 1, "");
        } else if (currentStep == Step.ReservationMint) {
            require(reservationList[msg.sender], "Not on reservation list");
            require(msg.value >= reservationNFTPrice, "Not enough ether");
            require(totalSupply() + 1 <= 477, "Max reservation mint supply exceeded");
            require(reservationMintByWallet[msg.sender] + 1 <= 1, "You already minted your reserved NFT");
            reservationMintByWallet[msg.sender] += 1;
            _mint(msg.sender, idToMint, 1, "");
        } else if (currentStep == Step.FirstWhitelistMint) {
            require(isOnList(msg.sender, _proof, 1), "Not on first whitelist");
            require(msg.value >= whitelistPrice, "Not enough ether");
            require(totalSupply() + 1 <= 577, "Max first whitelist mint supply exceeded");
            require(firstWhitelistMintByWallet[msg.sender] + 1 <= 1, "You already minted your first whitelist NFT");
            firstWhitelistMintByWallet[msg.sender] += 1;
            _mint(msg.sender, idToMint, 1, "");
        } else if (currentStep == Step.SecondWhitelistMint) {
            require(isOnList(msg.sender, _proof, 2), "Not on second whitelist");
            require(msg.value >= whitelistPrice, "Not enough ether");
            require(totalSupply() + 1 <= 777, "Max second whitelist mint supply exceeded");
            require(secondWhitelistMintByWallet[msg.sender] + 1 <= 1, "You already minted your second whitelist NFT");
            secondWhitelistMintByWallet[msg.sender] += 1;
            _mint(msg.sender, idToMint, 1, "");
        } else {
            require(msg.value >= publicPrice, "Not enough ether");
            require(totalSupply() + 1 <= 777, "Sold out");
            _mint(msg.sender, idToMint, 1, "");
        }
        supplyByID[idToMint]++;
        emit newMint(msg.sender, idToMint);
    }

    /*
    * @notice update step
    * @param _step step to update
    */
    function updateStep(Step _step) external onlyOwner {
        currentStep = _step;
        emit stepUpdated(currentStep);
    }

    /*
    * @notice update Marmott's address
    * @param address : new Marmott's address
    */
    function updateMarmott(address _marmott) external {
        require(msg.sender == marmott || msg.sender == owner(), "Only Marmott or owner can update Marmott");
        marmott = _marmott;
    }

    /*
    * @notice lock metadata
    */
    function lockMetadata() external onlyOwner {
        isMetadataLocked = true;
    }

    /*
    * @notice reveal NFTs
    */
    function reveal() external onlyOwner {
        isRevealed = true;
    }

    /*
    * @notice update URI
    * @param string : new URI
    */
    function updateURI(string memory _newUri) external onlyOwner {
        require(!isMetadataLocked, "Metadata locked");
        _uri = _newUri;
    }

    /*
    * @notice add satoshis to balanceOfSatoshis
    * @param uint : amount of satoshis to add
    */
    function addBTC(uint satoshis) external {
        require(msg.sender == marmott, "Only Marmott can add BTC");
        balanceOfSatoshis = balanceOfSatoshis + satoshis;
        uint divedBy = getNumberOfIdLeft();
        require(divedBy > 0, "No NFT left");
        uint satoshisPerId = satoshis / divedBy;
        for (uint i = 1; i <= maxToken; i++) {
            if (supplyByID[i] > 0) {
                balanceOfSatoshiByID[i] = balanceOfSatoshiByID[i] + satoshisPerId;
            }
        }
    }

    /*
    * @notice remove satoshis from balanceOfSatoshis
    * @param uint : amount of satoshis to remove
    */
    function subBTC(uint satoshis) external {
        require(msg.sender == marmott, "Only Marmott can sub BTC");
        require(balanceOfSatoshis >= satoshis, "Not enough satoshis in balance to sub");
        balanceOfSatoshis = balanceOfSatoshis - satoshis;
        uint divedBy = getNumberOfIdLeft();
        require(divedBy > 0, "No NFT left");
        uint satoshisPerId = satoshis / divedBy;
        for (uint i = 1; i <= maxToken; i++) {
            if (supplyByID[i] > 0) {
                require(balanceOfSatoshiByID[i] >= satoshisPerId, "Not enough satoshis in balance to sub (by id)");
                balanceOfSatoshiByID[i] = balanceOfSatoshiByID[i] - satoshisPerId;
            }
        }
    }

    /*
    * @notice redeem satoshis and burn NFT
    * @param uint : id of NFT to burn/redeem
    * @param string : bitcoin address to send satoshis to
    */
    function burnAndRedeem(uint _idToRedeem, string memory _btcAddress) public nonReentrant {
        require(_idToRedeem >= 1, "Nonexistent id");
        require(_idToRedeem <= maxToken, "Nonexistent id");
        require(currentStep == Step.SoldOut, "You can't redeem satoshis yet");
        require(balanceOf(msg.sender, _idToRedeem) >= 1, "Not enough Marmottoshis to burn");
        _burn(msg.sender, _idToRedeem, 1);
        uint satoshisToRedeem = redeemableById(_idToRedeem);
        require(satoshisToRedeem > 0, "No satoshi to redeem");
        balanceOfSatoshis = balanceOfSatoshis - satoshisToRedeem;
        balanceOfSatoshiByID[_idToRedeem] = balanceOfSatoshiByID[_idToRedeem] - satoshisToRedeem;
        supplyByID[_idToRedeem] = supplyByID[_idToRedeem] - 1;
        emit newRedeemRequest(msg.sender, _idToRedeem, 1, _btcAddress, satoshisToRedeem);
    }

    /*
    * @notice function for user to be preWhitelist
    */
    function reservationForWhitelist() external payable nonReentrant {
        require(currentStep == Step.WLReservation, "Reservation for whitelist is not open");
        require(msg.value >= reservationPrice, "Not enough ether");
        require(reservationList[msg.sender] == false, "You are already in the pre-whitelist");
        require(currentReservationNumber + 1 <= 400, "Max pre-whitelist reached");
        currentReservationNumber = currentReservationNumber + 1;
        reservationList[msg.sender] = true;
    }

    /*
    * @notice get number of Satoshis redeemable by NFT ID
    * @param uint : id of NFT
    */
    function redeemableById(uint _id) public view returns (uint) {
        if (supplyByID[_id] == 0) {
            return 0;
        } else {
            return balanceOfSatoshiByID[_id] / supplyByID[_id];
        }
    }

    /*
    * @notice get number of NFT's ID with supply left
    */
    function getNumberOfIdLeft() public view returns (uint) {
        uint numberOfIdLeft = 0;
        for (uint i = 1; i <= maxToken; i++) {
            if (supplyByID[i] > 0) {
                numberOfIdLeft = numberOfIdLeft + 1;
            }
        }
        return numberOfIdLeft;
    }

    /*
    * @notice create Artist struct of an artist and add it in artistByID mapping
    * @param _artists[] : array of artist's name
    * @param _links[] : array of artist's link
    * @param _id : id of the artist's NFT
    */
    function addArtist(string[] memory _artists, string[] memory _links, uint[] memory _id) external onlyOwner {
        require(_artists.length == _links.length && _artists.length == _id.length, "Artists and links must be the same length");
        for (uint i = 0; i < _artists.length; i++) {
            artistByID[_id[i]] = Artist({
            name : _artists[i],
            link : _links[i]
            });
        }
    }

    /*
    * @notice update free mint merkle root
    * @param _merkleRoot : new merkle root
    */
    function updateFreeMintMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        freeMintMerkleRoot = _merkleRoot;
    }

    /*
    * @notice update first whitelist merkle root
    * @param _merkleRoot : new merkle root
    */
    function updateFirstWhitelistMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        firstMerkleRoot = _merkleRoot;
    }

    /*
    * @notice update second whitelist merkle root
    * @param _merkleRoot : new merkle root
    */
    function updateSecondWhitelistMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        secondMerkleRoot = _merkleRoot;
    }

    /*
    * @notice update reservation price
    * @param _reservationPrice : new reservation price
    */
    function updateReservationPrice(uint _reservationPrice) external onlyOwner {
        reservationPrice = _reservationPrice;
    }

    /*
    * @notice update reservation NFT price
    * @param _reservationNFTPrice : new reservation NFT price
    */
    function updateReservationNFTPrice(uint _reservationNFTPrice) external onlyOwner {
        reservationNFTPrice = _reservationNFTPrice;
    }

    /*
    * @notice update whitelist price
    * @param _whitelistPrice : new whitelist price
    */
    function updateWLPrice(uint _whitelistPrice) external onlyOwner {
        whitelistPrice = _whitelistPrice;
    }

    /*
    * @notice update public price
    * @param _publicPrice : new public price
    */
    function updatePublicPrice(uint _publicPrice) external onlyOwner {
        publicPrice = _publicPrice;
    }

    /*
    * @notice return NFTs URI
    * @param _tokenId : id of NFT
    */
    function uri(uint256 _tokenId) override public view returns (string memory) {
        require(_tokenId >= 1, "Nonexistent id");
        require(_tokenId <= maxToken, "Nonexistent id");
        require(supplyByID[_tokenId] > 0, "Nonexistent id");
        if (!isRevealed) {
            return _uri;
        }
        string memory image = string(abi.encodePacked(_uri, _tokenId.toString(), ".png"));
        string memory name = string(abi.encodePacked("Marmottoshis #", _tokenId.toString()));
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "', name, '", "image": "', image, '", "description": "Realised by ', artistByID[_tokenId].name, ' you can see more here : ', artistByID[_tokenId].link, '", "attributes": [{"trait_type": "Satoshis", "value": "', redeemableById(_tokenId).toString(), '"}]}'
                    )
                )
            )
        );

        return string(abi.encodePacked('data:application/json;base64,', json));
    }

    /*
    * @notice Returns the sum of all supplies for each NFT ID
    */
    function totalSupply() public view returns (uint) {
        uint supply = 0;
        for (uint i = 1; i <= maxToken; i++) {
            supply = supply + supplyByID[i];
        }
        return supply;
    }

    /*
    * @notice withdraw ether from contract
    */
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /*
    * @notice know if user is on a list
    * @param _account address of user
    * @param _proof Merkle proof
    * @param _step : step of the list (0 = free mint, 1 = first whitelist, 2 = second whitelist)
    */
    function isOnList(address _account, bytes32[] calldata _proof, uint _step) public view returns (bool) {
        if (_step == 0) {
            return _verify(_leaf(_account), _proof, freeMintMerkleRoot);
        } else if (_step == 1) {
            return _verify(_leaf(_account), _proof, firstMerkleRoot);
        } else if (_step == 2) {
            return _verify(_leaf(_account), _proof, secondMerkleRoot);
        } else {
            return false;
        }
    }

    /*
    * @notice get merkle _leaf
    * @param _account address of user
    */
    function _leaf(address _account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account));
    }

    /*
    * @notice verify if user is on list
    * @param leaf bytes32 leaf of merkle tree
    * @param proof bytes32 Merkle proof
    * @param root bytes32 Merkle root
    */
    function _verify(bytes32 leaf, bytes32[] memory proof, bytes32 root) internal pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }

    // EIP2981 royalties
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }
    // END OF EIP2981 royalties
}
