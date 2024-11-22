// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../interfaces/l2/IPortraitIdRegistry.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/// @custom:security-contact ryan@portrait.gg
contract PortraitIdRegistryV2 is
    IPortraitIdRegistry,
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    ERC721PausableUpgradeable,
    OwnableUpgradeable,
    ERC721BurnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant CONTRACT_NAME = "PortraitIdRegistry";

    uint256 public constant VERSION = 2;

    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    IPortraitContractRegistry public portraitContractRegistry;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    IPortraitAccessRegistry public portraitAccessRegistry;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    IPortraitNameRegistry public portraitNameRegistry;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    PortraitSigValidator public portraitSigValidator;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    uint256 public portraitIdCounter;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    bool public isControlledRegistrationPeriod;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    string public baseURI;

    /*//////////////////////////////////////////////////////////////
                              MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mapping of an owner (address) to a mapping of portraitId (uint256) to a true/false value
     * @dev Can not be defined in the interface, as nested mappings are not supported.
     *      Use `isOwnerOfPortraitId` to access this mapping for a specific owner.
     */
    mapping(address => mapping(uint256 => bool))
        public ownerToPortraitIdsToIsOwner;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    mapping(uint256 => address) public portraitIdToOwner;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    mapping(address => uint256) public ownerToPrimaryPortraitId;

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    mapping(address => uint256) public ownerToPortraitIdCount;

    /*//////////////////////////////////////////////////////////////
                          REGISTRATION ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function register(
        address owner,
        bytes32 reservationHash,
        address delegate
    ) external whenNotPaused returns (uint256 portraitId) {
        bool isDelegate = portraitAccessRegistry.isDelegateOfAddress(
            owner,
            msg.sender
        );
        bool isOwner = owner == msg.sender;

        if (isOwner) {
            return _register(msg.sender, reservationHash, delegate);
        }

        if (!isDelegate) revert Unauthorized();

        return _register(owner, reservationHash, delegate);
    }

    modifier whenNotControlledRegistrationPeriod() {
        if (isControlledRegistrationPeriod) {
            if (msg.sender != owner()) revert ControlledRegistrationPeriod();
        }
        _;
    }

    function _register(
        address owner,
        bytes32 reservationHash,
        address delegate
    )
        internal
        nonReentrant
        whenNotControlledRegistrationPeriod
        returns (uint256 portraitId)
    {
        portraitIdCounter++;

        portraitId = portraitIdCounter;

        portraitIdToOwner[portraitId] = owner;

        bool isDelegate = portraitAccessRegistry.isDelegateOfAddress(
            owner,
            msg.sender
        );
        bool isOwner = owner == msg.sender;

        // Needed for registerFor() - as a security measure, the msg.sender must be the delegate, which is the service address.
        bool delegateIsServiceAddress = delegate ==
            portraitAccessRegistry.delegateServiceAddress() &&
            msg.sender == delegate;

        if (delegate != address(0) && delegate != owner) {
            if (!isDelegate && !isOwner && !delegateIsServiceAddress)
                revert Unauthorized();
            bool hasDelegateAssigned = portraitAccessRegistry
                .getOwnerToAddressToDelegateData(owner, delegate)
                .hasAssigned;
            if (!hasDelegateAssigned)
                portraitAccessRegistry.toggleDelegate(owner, delegate);
        }

        ownerToPortraitIdsToIsOwner[owner][portraitId] = true;

        // If no primary, set as primary
        if (ownerToPrimaryPortraitId[owner] == 0) {
            ownerToPrimaryPortraitId[owner] = portraitId;
        }

        portraitNameRegistry.reserveName(reservationHash, msg.sender);

        emit PortraitRegistered(portraitId, owner);

        ownerToPortraitIdCount[owner]++;

        return portraitIdCounter;
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function registerFor(
        address signer,
        address owner,
        bytes32 reservationHash,
        address delegate,
        uint256 deadline,
        bytes calldata sig
    ) external whenNotPaused returns (uint256 portraitId) {
        if (
            !_verifyRegisterFor(
                signer,
                owner,
                reservationHash,
                delegate,
                deadline,
                sig
            )
        ) revert InvalidSignature();

        return _register(owner, reservationHash, delegate);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function _transferPortraitId(
        uint256 portraitId,
        address from,
        address to
    ) internal nonReentrant whenNotControlledRegistrationPeriod {
        // Validate if `from` is the owner; if not, set it to the actual owner
        if (from != portraitIdToOwner[portraitId]) {
            from = portraitIdToOwner[portraitId];
        }

        // Update the owner
        address previousOwner = portraitIdToOwner[portraitId];
        portraitIdToOwner[portraitId] = to;

        // Update mappings for portrait ownership
        ownerToPortraitIdsToIsOwner[previousOwner][portraitId] = false;
        ownerToPortraitIdsToIsOwner[to][portraitId] = true;

        // Update primary portrait ID
        if (ownerToPrimaryPortraitId[previousOwner] == portraitId) {
            if (balanceOf(previousOwner) > 0) {
                for (uint256 i = 0; i < balanceOf(previousOwner); i++) {
                    uint256 portraitIdAtIndex = tokenOfOwnerByIndex(
                        previousOwner,
                        i
                    );
                    if (portraitIdToOwner[portraitIdAtIndex] == previousOwner) {
                        ownerToPrimaryPortraitId[
                            previousOwner
                        ] = portraitIdAtIndex;
                        break;
                    }
                }
            } else {
                delete ownerToPrimaryPortraitId[previousOwner];
            }
        }

        // Set PortraitIdCount
        // Just taking a null address into account.
        if (ownerToPortraitIdCount[from] > 0) ownerToPortraitIdCount[from]--;
        ownerToPortraitIdCount[to]++;

        // Emit event
        emit PortraitTransferred(portraitId, from, to);
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function transferPortraitId(uint256 portraitId, address to) external {
        if (
            !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                portraitId,
                msg.sender
            )
        ) revert Unauthorized();

        if (isTokenizedPortraitId(portraitId)) revert AsNFT();

        _transferPortraitId(portraitId, msg.sender, to);
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function transferPortraitIdFor(
        uint256 portraitId,
        address from,
        address to,
        uint256 deadline,
        bytes calldata sig
    ) external nonReentrant {
        if (isTokenizedPortraitId(portraitId)) revert AsNFT();

        if (!_verifyTransferFor(portraitId, from, to, deadline, sig))
            revert InvalidSignature();

        _transferPortraitId(portraitId, from, to);
    }

    /*//////////////////////////////////////////////////////////////
                              STATE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function setPrimaryPortrait(address owner, uint256 portraitId) external {
        if (
            !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                portraitId,
                msg.sender
            )
        ) revert Unauthorized();

        if (!ownerToPortraitIdsToIsOwner[owner][portraitId])
            revert Unauthorized();

        ownerToPrimaryPortraitId[owner] = portraitId;
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function setPrimaryPortraitFor(
        address signer,
        address owner,
        uint256 portraitId,
        uint256 deadline,
        bytes calldata sig
    ) external {
        if (block.timestamp > deadline) revert ExpiredSignature();

        if (signer != owner) {
            bool isDelegate = portraitAccessRegistry.isDelegateOfAddress(
                owner,
                signer
            );
            if (!isDelegate) revert Unauthorized();
        }

        // All but sig
        bytes32 paramsHash = keccak256(
            abi.encodePacked(signer, owner, portraitId, deadline)
        );

        SigData memory data = SigData({
            action: "SetPrimaryPortraitFor",
            target: CONTRACT_NAME,
            targetType: "Contract",
            version: VERSION,
            params: paramsHash,
            expirationTime: deadline
        });

        if (!portraitSigValidator.isValidSig(signer, data, sig))
            revert InvalidSignature();

        ownerToPrimaryPortraitId[owner] = portraitId;
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns if a portraitId is tokenized
     * @dev A portraitId is tokenized if the owner of the portraitId is the owner of the ERC721 token
     *      A null address is not tokenized
     *
     * @param portraitId The portraitId to check if is tokenized
     *
     * @return isTokenized If the portraitId is tokenized
     */
    function isTokenizedPortraitId(
        uint256 portraitId
    ) internal view returns (bool isTokenized) {
        address owner = portraitIdToOwner[portraitId];
        if (owner == _ownerOf(portraitId) && _ownerOf(portraitId) != address(0))
            return true;

        return false;
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function verifyRegisterFor(
        address caller,
        address owner,
        bytes32 reservationHash,
        address delegate,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid) {
        return
            _verifyRegisterFor(
                caller,
                owner,
                reservationHash,
                delegate,
                deadline,
                sig
            );
    }

    function _verifyRegisterFor(
        address signer,
        address owner,
        bytes32 reservationHash,
        address delegate,
        uint256 deadline,
        bytes calldata sig
    ) internal returns (bool isValid) {
        if (block.timestamp > deadline) revert ExpiredSignature();

        if (signer != owner) {
            bool isDelegate = portraitAccessRegistry.isDelegateOfAddress(
                owner,
                signer
            );
            if (!isDelegate) revert Unauthorized();
        }

        // All but sig
        bytes32 paramsHash = keccak256(
            abi.encodePacked(signer, owner, reservationHash, delegate, deadline)
        );

        SigData memory data = SigData({
            action: "RegisterFor",
            target: CONTRACT_NAME,
            targetType: "Contract",
            version: VERSION,
            params: paramsHash,
            expirationTime: deadline
        });

        return portraitSigValidator.isValidSig(signer, data, sig);
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function verifyTransferFor(
        uint256 portraitId,
        address from,
        address to,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid) {
        return _verifyTransferFor(portraitId, from, to, deadline, sig);
    }

    function _verifyTransferFor(
        uint256 portraitId,
        address from,
        address to,
        uint256 deadline,
        bytes calldata sig
    ) internal returns (bool isValid) {
        if (block.timestamp > deadline) revert ExpiredSignature();

        // All but sig
        bytes32 paramsHash = keccak256(
            abi.encodePacked(portraitId, from, to, deadline)
        );

        SigData memory data = SigData({
            action: "TransferFor",
            target: CONTRACT_NAME,
            targetType: "Contract",
            version: VERSION,
            params: paramsHash,
            expirationTime: deadline
        });

        return portraitSigValidator.isValidSig(from, data, sig);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function isOwnerOfPortraitId(
        address potentialOwner,
        uint256 portraitId
    ) external view returns (bool isOwner) {
        return ownerToPortraitIdsToIsOwner[potentialOwner][portraitId];
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function getOwnersForPortraitIds(
        uint256[] calldata portraitIds
    ) external view returns (address[] memory owners) {
        owners = new address[](portraitIds.length);

        for (uint256 i = 0; i < portraitIds.length; i++) {
            owners[i] = portraitIdToOwner[portraitIds[i]];
        }

        return owners;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC-721
    //////////////////////////////////////////////////////////////*/

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721Upgradeable, IERC721) whenNotPaused {
        super.transferFrom(from, to, tokenId);
    }

    function safeMint(uint256 portraitId) public {
        address ownerOfPortraitId = portraitIdToOwner[portraitId];
        // Using internal function of _ownerOf because external function reverts if owner is 0 address, aka not yet minted or already burned
        if (ownerOfPortraitId == _ownerOf(portraitId)) revert ExceedsSupply();

        super._safeMint(portraitIdToOwner[portraitId], portraitId);
    }

    /// @dev As both ERC721Upgradeable and ERC721EnumerableUpgradeable inherit from ERC721PausableUpgradeable, we need to override the function.
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._increaseBalance(account, value);
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC721PausableUpgradeable
        )
        whenNotPaused
        returns (address)
    {
        address owner = _ownerOf(tokenId);

        // _isAuthorized is an internal function of ERC721Upgradeable, validating if the transaction initiator is the owner or an approved address.
        if (!_isAuthorized(owner, msg.sender, tokenId)) {
            if (
                // If the transaction initiator is not the owner, check if the transaction initiator is a delegate or owner of the portraitId.
                // Owner of Portrait ID doesn't mean the erc721 token is minted, thus the owner of the tokenId can be 0 address.
                !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                    tokenId,
                    msg.sender
                )
            ) revert Unauthorized();
        }

        address previousOwner = super._update(to, tokenId, auth);

        _transferPortraitId(tokenId, owner, to);
        return previousOwner;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function trustedRegister(
        address signer,
        address owner,
        bytes32 reservationHash,
        address delegate,
        uint256 deadline,
        bytes calldata sig
    ) external onlyOwner returns (uint256 portraitId) {
        if (
            !_verifyRegisterFor(
                signer,
                owner,
                reservationHash,
                delegate,
                deadline,
                sig
            )
        ) revert InvalidSignature();

        return _register(owner, reservationHash, delegate);
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function toggleIsControlledRegistrationPeriod() external onlyOwner {
        isControlledRegistrationPeriod = !isControlledRegistrationPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitIdRegistry
     */
    function updateProtocolContracts() external {
        portraitAccessRegistry = portraitContractRegistry
            .portraitAccessRegistry();
        portraitNameRegistry = portraitContractRegistry.portraitNameRegistry();
        portraitSigValidator = portraitContractRegistry.portraitSigValidator();
    }

    /*//////////////////////////////////////////////////////////////
                                OPENZEPPELIN
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address portraitContractRegistryAddress
    ) public initializer {
        if (portraitContractRegistryAddress == address(0))
            revert InvalidAddress();

        if (initialOwner == address(0)) revert InvalidAddress();

        __ERC721_init("Portrait", "PRTRT");
        __ERC721Enumerable_init();
        __ERC721Pausable_init();
        __Ownable_init(initialOwner);
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        portraitIdCounter = 0;
        isControlledRegistrationPeriod = true;
        baseURI = "https://token.portrait.so/";

        portraitContractRegistry = IPortraitContractRegistry(
            portraitContractRegistryAddress
        );

        if (portraitAccessRegistry == IPortraitAccessRegistry(address(0))) {
            bool hasAccessRegistry = portraitContractRegistry
                .portraitAccessRegistry() !=
                IPortraitAccessRegistry(address(0));

            if (hasAccessRegistry) {
                portraitAccessRegistry = portraitContractRegistry
                    .portraitAccessRegistry();
            }
        }

        if (portraitNameRegistry == IPortraitNameRegistry(address(0))) {
            bool hasNameRegistry = portraitContractRegistry
                .portraitNameRegistry() != IPortraitNameRegistry(address(0));

            if (hasNameRegistry) {
                portraitNameRegistry = portraitContractRegistry
                    .portraitNameRegistry();
            }
        }

        if (portraitSigValidator == PortraitSigValidator(address(0))) {
            bool hasPortraitSigValidator = portraitContractRegistry
                .portraitSigValidator() != PortraitSigValidator(address(0));

            if (hasPortraitSigValidator) {
                portraitSigValidator = portraitContractRegistry
                    .portraitSigValidator();
            }
        }

        _pause();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
