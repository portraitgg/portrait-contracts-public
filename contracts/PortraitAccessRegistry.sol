// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../interfaces/l2/IPortraitAccessRegistry.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact ryan@portrait.gg
contract PortraitAccessRegistry is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IPortraitAccessRegistry
{
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant CONTRACT_NAME = "PortraitAccessRegistry";

    uint256 public constant VERSION = 1;

    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    IPortraitContractRegistry public portraitContractRegistry;

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    IPortraitIdRegistry public portraitIdRegistry;

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    PortraitSigValidator public portraitSigValidator;

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    address public delegateServiceAddress;

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    uint256 public maxDelegates;

    /*//////////////////////////////////////////////////////////////
                                 MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mapping of an owner to a mapping of addresses to a DelegateData struct
     * @dev Can not be defined in the interface, as structs are not supported.
     *      Use `getOwnerToAddressToDelegateData` to access the nested mapping.
     */
    mapping(address => mapping(address => DelegateData))
        public ownerToAddressToDelegateData;

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    mapping(address => uint256) public ownerToAmountOfDelegates;

    /*//////////////////////////////////////////////////////////////
                         DELEGATE ACTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function toggleDelegate(
        address owner,
        address delegate
    ) external whenNotPaused returns (DelegateData memory delegateData) {
        return _toggleDelegate(msg.sender, owner, delegate);
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function toggleDelegateArray(
        address owner,
        address[] calldata delegates
    ) external whenNotPaused {
        for (uint256 i = 0; i < delegates.length; i++) {
            _toggleDelegate(msg.sender, owner, delegates[i]);
        }
    }

    function _toggleDelegate(
        address caller,
        address owner,
        address delegate
    ) internal returns (DelegateData memory delegateData) {
        if (ownerToAmountOfDelegates[owner] >= maxDelegates)
            revert MaxDelegatesReached();
        /*
         * The condition below is to allow the PortraitIdRegistry contract to toggle the delegate status of our delegateServiceAddress,
         * the delegateServiceAddress is able to cover the gas costs of the owner.
         */
        if (
            caller == address(portraitIdRegistry) &&
            delegate == delegateServiceAddress
        ) {
            ownerToAddressToDelegateData[owner][delegateServiceAddress]
                .hasAssigned = true;
            ownerToAddressToDelegateData[owner][delegateServiceAddress]
                .hasAccepted = true;

            // Emit event to keep track of delegates
            emit DelegateToggled(
                owner,
                delegateServiceAddress,
                ownerToAddressToDelegateData[owner][delegateServiceAddress]
                    .hasAssigned,
                ownerToAddressToDelegateData[owner][delegateServiceAddress]
                    .hasAccepted
            );
            return ownerToAddressToDelegateData[owner][delegateServiceAddress];
        }

        // If the caller is not the owner or delegate, revert
        if (caller != owner) {
            bool isDelegate = _isDelegateOfAddress(owner, caller);
            if (!isDelegate) revert Unauthorized();
        }

        // If delegate is the owner, you have the same rights as a delegate, so this is not needed
        if (delegate == owner) revert InvalidAction();

        ownerToAddressToDelegateData[owner][delegate]
            .hasAssigned = !ownerToAddressToDelegateData[owner][delegate]
            .hasAssigned;

        if (!ownerToAddressToDelegateData[owner][delegate].hasAssigned) {
            ownerToAmountOfDelegates[owner]--;
        } else {
            ownerToAmountOfDelegates[owner]++;
        }

        ownerToAddressToDelegateData[owner][delegate].hasAccepted = false;

        emit DelegateToggled(
            owner,
            delegate,
            ownerToAddressToDelegateData[owner][delegate].hasAssigned,
            ownerToAddressToDelegateData[owner][delegate].hasAccepted
        );

        return ownerToAddressToDelegateData[owner][delegate];
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function toggleDelegateRequest(
        address owner,
        address delegate
    ) external whenNotPaused returns (DelegateData memory delegateData) {
        return _toggleDelegateRequest(msg.sender, owner, delegate);
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function toggleDelegateRequestArray(
        address owner,
        address[] calldata delegates
    ) external whenNotPaused {
        for (uint256 i = 0; i < delegates.length; i++) {
            _toggleDelegateRequest(msg.sender, owner, delegates[i]);
        }
    }

    function _toggleDelegateRequest(
        address caller,
        address owner,
        address delegate
    ) internal returns (DelegateData memory delegateData) {
        if (caller != delegate) {
            bool isDelegate = _isDelegateOfAddress(delegate, caller);
            if (!isDelegate) revert Unauthorized();
        }

        if (delegate == owner) revert Unauthorized();

        ownerToAddressToDelegateData[owner][delegate]
            .hasAccepted = !ownerToAddressToDelegateData[owner][delegate]
            .hasAccepted;

        emit DelegateToggled(
            owner,
            delegate,
            ownerToAddressToDelegateData[owner][delegate].hasAssigned,
            ownerToAddressToDelegateData[owner][delegate].hasAccepted
        );

        return ownerToAddressToDelegateData[owner][delegate];
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function toggleDelegateFor(
        address caller,
        address owner,
        address delegate,
        bool currentHasAssigned,
        uint256 deadline,
        bytes calldata sig
    ) external returns (DelegateData memory delegateData) {
        if (
            !_verifyToggleDelegateFor(
                caller,
                owner,
                delegate,
                currentHasAssigned,
                deadline,
                sig
            )
        ) revert InvalidSignature();

        return _toggleDelegate(caller, owner, delegate);
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function toggleDelegateRequestFor(
        address caller,
        address owner,
        address delegate,
        bool currentHasAccepted,
        uint256 deadline,
        bytes calldata sig
    ) external returns (DelegateData memory delegateData) {
        if (
            !_verifyToggleDelegateRequestFor(
                caller,
                owner,
                delegate,
                currentHasAccepted,
                deadline,
                sig
            )
        ) revert InvalidSignature();

        return _toggleDelegateRequest(caller, owner, delegate);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function getOwnerToAddressToDelegateData(
        address owner,
        address potentialDelegate
    ) external view returns (DelegateData memory delegateData) {
        return ownerToAddressToDelegateData[owner][potentialDelegate];
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function isDelegateOfPortraitId(
        uint256 portraitId,
        address delegate
    ) external view returns (bool isDelegate) {
        address ownerOfPortrait = portraitIdRegistry.portraitIdToOwner(
            portraitId
        );

        bool _isDelegateOfPortraitId = _isDelegateOfAddress(
            ownerOfPortrait,
            delegate
        );
        return _isDelegateOfPortraitId;
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function isDelegateOfAddress(
        address owner,
        address delegate
    ) external view returns (bool isDelegate) {
        return _isDelegateOfAddress(owner, delegate);
    }

    function _isDelegateOfAddress(
        address owner,
        address delegate
    ) internal view returns (bool isDelegate) {
        bool hasAssigned = ownerToAddressToDelegateData[owner][delegate]
            .hasAssigned;
        bool hasAccepted = ownerToAddressToDelegateData[owner][delegate]
            .hasAccepted;
        bool __isDelegateOfAddress = hasAssigned && hasAccepted;
        return __isDelegateOfAddress;
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function isDelegateOrOwnerOfPortraitId(
        uint256 portraitId,
        address caller
    ) external view returns (bool isDelegateOrOwner) {
        return _isDelegateOrOwnerOfPortraitId(portraitId, caller);
    }

    function _isDelegateOrOwnerOfPortraitId(
        uint256 portraitId,
        address caller
    ) internal view returns (bool isDelegateOrOwner) {
        /* Revert if the caller is not the owner or delegate of the portraitId */
        bool isOwner = portraitIdRegistry.isOwnerOfPortraitId(
            caller,
            portraitId
        );
        address ownerOfPortrait = portraitIdRegistry.portraitIdToOwner(
            portraitId
        );
        bool isDelegate = _isDelegateOfAddress(ownerOfPortrait, caller);

        return isOwner || isDelegate;
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function setDelegateServiceAddress(
        address newDelegateServiceAddress
    ) external onlyOwner {
        if (newDelegateServiceAddress == address(0)) revert InvalidAddress();

        delegateServiceAddress = newDelegateServiceAddress;
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function setMaxDelegates(uint256 newMaxDelegates) external onlyOwner {
        maxDelegates = newMaxDelegates;
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function isPortraitIdIsBurnedOrUnassigned(
        uint256 portraitId
    ) internal view returns (bool) {
        if (portraitIdRegistry.portraitIdToOwner(portraitId) == address(0))
            return true;
        return false;
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function verifyToggleDelegateFor(
        address signer,
        address owner,
        address delegate,
        bool currentHasAssigned,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid) {
        return
            _verifyToggleDelegateFor(
                signer,
                owner,
                delegate,
                currentHasAssigned,
                deadline,
                sig
            );
    }

    function _verifyToggleDelegateFor(
        address signer,
        address owner,
        address delegate,
        bool currentHasAssigned,
        uint256 deadline,
        bytes calldata sig
    ) internal returns (bool isValid) {
        if (block.timestamp > deadline) revert ExpiredSignature();

        if (signer != owner) {
            bool isDelegate = _isDelegateOfAddress(owner, signer);
            if (!isDelegate) revert Unauthorized();
        }

        if (
            ownerToAddressToDelegateData[owner][delegate].hasAssigned !=
            currentHasAssigned
        ) revert Unauthorized();

        // All but sig
        bytes32 paramsHash = keccak256(
            abi.encodePacked(
                signer,
                owner,
                delegate,
                currentHasAssigned,
                deadline
            )
        );

        SigData memory data = SigData({
            action: "ToggleDelegateFor",
            target: CONTRACT_NAME,
            targetType: "Contract",
            version: VERSION,
            params: paramsHash,
            expirationTime: deadline
        });

        return portraitSigValidator.isValidSig(signer, data, sig);
    }

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function verifyToggleDelegateRequestFor(
        address signer,
        address owner,
        address delegate,
        bool currentHasAccepted,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid) {
        return
            _verifyToggleDelegateRequestFor(
                signer,
                owner,
                delegate,
                currentHasAccepted,
                deadline,
                sig
            );
    }

    function _verifyToggleDelegateRequestFor(
        address signer,
        address owner,
        address delegate,
        bool currentHasAccepted,
        uint256 deadline,
        bytes calldata sig
    ) internal returns (bool isValid) {
        if (block.timestamp > deadline) revert ExpiredSignature();

        if (signer != owner) {
            bool isDelegate = _isDelegateOfAddress(owner, signer);
            if (!isDelegate) revert Unauthorized();
        }

        if (
            ownerToAddressToDelegateData[owner][delegate].hasAccepted !=
            currentHasAccepted
        ) revert Unauthorized();

        // All but sig
        bytes32 paramsHash = keccak256(
            abi.encodePacked(
                signer,
                owner,
                delegate,
                currentHasAccepted,
                deadline
            )
        );

        SigData memory data = SigData({
            action: "ToggleDelegateRequestFor",
            target: CONTRACT_NAME,
            targetType: "Contract",
            version: VERSION,
            params: paramsHash,
            expirationTime: deadline
        });

        return portraitSigValidator.isValidSig(signer, data, sig);
    }

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitAccessRegistry
     */
    function updateProtocolContracts() external {
        portraitIdRegistry = portraitContractRegistry.portraitIdRegistry();
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

        __Pausable_init();
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        delegateServiceAddress = initialOwner;

        maxDelegates = 5;

        portraitContractRegistry = IPortraitContractRegistry(
            portraitContractRegistryAddress
        );

        if (portraitIdRegistry == IPortraitIdRegistry(address(0))) {
            bool hasIdRegistry = portraitContractRegistry
                .portraitIdRegistry() != IPortraitIdRegistry(address(0));

            if (hasIdRegistry) {
                portraitIdRegistry = portraitContractRegistry
                    .portraitIdRegistry();
            }
        }

        if (portraitSigValidator == PortraitSigValidator(address(0))) {
            bool hasPortraitSigValidator = portraitContractRegistry
                .portraitSigValidator() != PortraitSigValidator(address(0));

            if (hasPortraitSigValidator) {
                portraitSigValidator = PortraitSigValidator(
                    portraitContractRegistry.portraitSigValidator()
                );
            }
        }

        // Pause the contract
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
