// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../interfaces/l2/IPortraitNodeRegistry.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact ryan@portrait.gg
contract PortraitNodeRegistry is
    IPortraitNodeRegistry,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant CONTRACT_NAME = "PortraitNodeRegistry";

    uint256 public constant VERSION = 1;

    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    IPortraitContractRegistry public portraitContractRegistry;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    IPortraitAccessRegistry public portraitAccessRegistry;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    PortraitSigValidator public portraitSigValidator;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    uint256 public maxNodesPerPortraitId;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    uint256 public totalNodesRegistered;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    uint256 public totalTurbohosts;

    /*//////////////////////////////////////////////////////////////
                              MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mapping of a nodeAddress (address) to a mapping of portraitId (uint256) to a boolean value indicating if the node is registered.
     * @dev Can not be defined in the interface, as nested mappings are not supported.
     *      Use `hasRegisteredNode` to check if a portraitId has registered a specific node.
     */
    mapping(address nodeAddress => mapping(uint256 portraitId => bool isRegistered))
        public nodeAddressToPortraitIdToIsRegistered;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    mapping(uint256 portraitId => uint256 nodeCount)
        public portraitIdToNodeCount;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    mapping(address nodeAddress => uint256 portraitIdCount)
        public nodeAddressToPortraitIdCount;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    mapping(address turboNodeAddress => uint256 portraitId)
        public turboNodeAddressToPortraitId;

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    mapping(uint256 portraitId => address turboNodeAddress)
        public portraitIdToTurboNodeAddress;

    /*//////////////////////////////////////////////////////////////
                          NODE ACTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function registerNodeToPortraitId(
        address nodeAddress,
        uint256 portraitId,
        uint256 deadline,
        bytes calldata sig
    ) external virtual whenNotPaused {
        _registerNodeToPortraitId(nodeAddress, portraitId, deadline, sig);
    }

    function _registerNodeToPortraitId(
        address nodeAddress,
        uint256 portraitId,
        uint256 deadline,
        bytes calldata sig
    ) internal {
        if (
            !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                portraitId,
                msg.sender
            )
        ) revert Unauthorized();

        if (nodeAddressToPortraitIdToIsRegistered[nodeAddress][portraitId])
            revert NodeAlreadyRegistered();

        uint256 nodeCount = portraitIdToNodeCount[portraitId];
        if (nodeCount >= maxNodesPerPortraitId) revert MaxNodesReached();

        bool isTurbohost = bool(turboNodeAddressToPortraitId[nodeAddress] > 0);

        if (isTurbohost) {
            if (nodeCount > 0) revert IsNormalNode();
        }

        bool isValidSig = _verifyRegisterNodeToPortraitIdProof(
            nodeAddress,
            portraitId,
            deadline,
            sig
        );

        if (!isValidSig) revert InvalidSignature();

        // Only increment totalNodesRegistered if the nodeAddress is not already registered to another portraitId.
        if (nodeAddressToPortraitIdCount[nodeAddress] == 0) {
            totalNodesRegistered += 1;
        }

        nodeAddressToPortraitIdToIsRegistered[nodeAddress][portraitId] = true;
        nodeAddressToPortraitIdCount[nodeAddress] += 1;
        portraitIdToNodeCount[portraitId] += 1;

        emit NodeRegistered(nodeAddress, portraitId, block.timestamp);
    }

    //

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function unregisterNodeFromPortraitId(
        address nodeAddress,
        uint256 portraitId
    ) external whenNotPaused {
        _unregisterNodeFromPortraitId(nodeAddress, portraitId);
    }

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function unregisterNodeFromAllPortraitIds(
        address nodeAddress,
        uint256[] calldata portraitIds
    ) external whenNotPaused {
        uint256 lengthOfPortraitIds = portraitIds.length;

        // This is a check to ensure that the length of the portraitIds array is equal to the number of portraitIds registered to the node.
        if (lengthOfPortraitIds != nodeAddressToPortraitIdCount[nodeAddress])
            revert InvalidArrayLength();

        for (uint256 i = 0; i < portraitIds.length; i++) {
            _unregisterNodeFromPortraitId(nodeAddress, portraitIds[i]);
        }

        // The node should no longer have any portraitIds registered to it.
        if (nodeAddressToPortraitIdCount[nodeAddress] != 0)
            revert InvalidArrayLength();
    }

    function _unregisterNodeFromPortraitId(
        address nodeAddress,
        uint256 portraitId
    ) internal {
        if (
            !portraitAccessRegistry.isDelegateOrOwnerOfPortraitId(
                portraitId,
                msg.sender
            )
        ) revert Unauthorized();

        bool isTurbohost = bool(turboNodeAddressToPortraitId[nodeAddress] > 0);

        if (isTurbohost) {
            portraitIdToTurboNodeAddress[portraitId] = address(0);

            totalTurbohosts -= 1;

            turboNodeAddressToPortraitId[nodeAddress] = 0;

            emit TurbohostUpdated(nodeAddress, false, block.timestamp);

            return;
        }

        if (!nodeAddressToPortraitIdToIsRegistered[nodeAddress][portraitId])
            revert NodeNotRegistered();

        // The node is no longer registered to the portraitId.
        nodeAddressToPortraitIdToIsRegistered[nodeAddress][portraitId] = false;

        // Only decrement totalNodesRegistered if the nodeAddress is not registered to another portraitId anymore.
        if (portraitIdToNodeCount[portraitId] > 0) {
            totalNodesRegistered -= 1;
        }

        // The portraitId now has one less node registered to it.
        portraitIdToNodeCount[portraitId] -= 1;

        // The nodeAddress now has one less portraitId registered to it.
        nodeAddressToPortraitIdCount[nodeAddress] -= 1;

        emit NodeUnregistered(nodeAddress, portraitId, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function verifyRegisterNodeToPortraitIdProof(
        address signer,
        uint256 portraitId,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid) {
        return
            _verifyRegisterNodeToPortraitIdProof(
                signer,
                portraitId,
                deadline,
                sig
            );
    }

    function _verifyRegisterNodeToPortraitIdProof(
        address signer,
        uint256 portraitId,
        uint256 deadline,
        bytes calldata sig
    ) internal returns (bool isValid) {
        if (block.timestamp > deadline) revert ExpiredSignature();

        SigData memory data = SigData({
            action: "registerNodeToPortraitId",
            target: CONTRACT_NAME,
            targetType: "Contract",
            version: VERSION,
            params: bytes32(portraitId),
            expirationTime: deadline
        });

        return portraitSigValidator.isValidSig(signer, data, sig);
    }

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function hasRegisteredNode(
        address nodeAddress,
        uint256 portraitId
    ) external view returns (bool hasRegistered) {
        return nodeAddressToPortraitIdToIsRegistered[nodeAddress][portraitId];
    }

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function isPortraitIdTurbohost(
        uint256 portraitId
    ) external view returns (bool isTurbohost) {
        return portraitIdToTurboNodeAddress[portraitId] != address(0);
    }

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function isNodeAddressTurbohost(
        address nodeAddress
    ) external view returns (bool isTurbohost) {
        return turboNodeAddressToPortraitId[nodeAddress] != 0;
    }

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function setMaxNodesPerPortraitId(uint256 maxNodes) external onlyOwner {
        maxNodesPerPortraitId = maxNodes;

        emit MaxNodesPerPortraitIdUpdated(maxNodes, block.timestamp);
    }

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function setTurbohostForNode(
        address nodeAddress,
        uint256 portraitId,
        bool isTurbohost
    ) external onlyOwner {
        if (isTurbohost) {
            if (portraitIdToTurboNodeAddress[portraitId] != address(0))
                revert TurbohostAlreadyRegistered();

            if (nodeAddressToPortraitIdCount[nodeAddress] > 0)
                revert IsNormalNode();

            portraitIdToTurboNodeAddress[portraitId] = nodeAddress;
            turboNodeAddressToPortraitId[nodeAddress] = portraitId;

            totalTurbohosts += 1;
        } else {
            if (portraitIdToTurboNodeAddress[portraitId] != nodeAddress)
                revert TurbohostNotRegistered();

            portraitIdToTurboNodeAddress[portraitId] = address(0);
            turboNodeAddressToPortraitId[nodeAddress] = 0;

            totalTurbohosts -= 1;
        }

        emit TurbohostUpdated(nodeAddress, isTurbohost, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitNodeRegistry
     */
    function updateProtocolContracts() external {
        portraitAccessRegistry = portraitContractRegistry
            .portraitAccessRegistry();
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

        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        maxNodesPerPortraitId = 5;
        totalNodesRegistered = 0;
        totalTurbohosts = 0;

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
