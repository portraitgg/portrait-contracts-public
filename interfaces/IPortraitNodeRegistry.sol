// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPortraitContractRegistry} from "./IPortraitContractRegistry.sol";
import {IPortraitAccessRegistry} from "./IPortraitAccessRegistry.sol";
import {IPortraitSigStruct} from "../../lib/IPortraitSigStruct.sol";
import {PortraitSigValidator} from "../../lib/PortraitSigValidator.sol";

interface IPortraitNodeRegistry is IPortraitSigStruct {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the name of the contract
     */
    function CONTRACT_NAME() external pure returns (string memory);

    /**
     * @notice Returns the version of the contract
     */
    function VERSION() external pure returns (uint256 version);

    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the PortraitContractRegistry contract
     */
    function portraitContractRegistry()
        external
        view
        returns (IPortraitContractRegistry portraitContractRegistry);

    /**
     * @notice Returns the address of the PortraitAccessRegistry contract
     */
    function portraitAccessRegistry()
        external
        view
        returns (IPortraitAccessRegistry portraitAccessRegistry);

    /**
     * @notice Returns the address of the PortraitSigValidator contract
     */
    function portraitSigValidator()
        external
        view
        returns (PortraitSigValidator portraitSigValidator);

    /**
     * @notice Returns the maximum amount of nodes that can be registered for a portraitId.
     * @dev Default is 5, but can be updated by the owner of the contract.
     */
    function maxNodesPerPortraitId() external view returns (uint256);

    /**
     * @notice Returns the total amount of nodes registered.
     * @dev This does not account for anonymous nodes, which run without registering.
     *      This is not the total amount of portraitIds with nodes registered, but just the total amount of nodes.
     *      This is excluding turbohosts.
     */
    function totalNodesRegistered() external view returns (uint256);

    /**
     * @notice Returns the total amount of turbohosts registered.
     * @dev This is the total amount of portraitIds with nodes registered as turbohosts.
     *      A turbohost can only be assigned to one portraitId.
     *      The owner of the contract can set a node as a turbohost.
     */
    function totalTurbohosts() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                             MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of nodes registered to a portraitId
     * @dev Mapping of portraitId => nodeCount
     */
    function portraitIdToNodeCount(
        uint256 portraitId
    ) external view returns (uint256 nodeCount);

    /**
     * @notice Returns the amount of portraitIds a node is registered to
     * @dev Mapping of nodeAddress => portraitIdCount
     */
    function nodeAddressToPortraitIdCount(
        address nodeAddress
    ) external view returns (uint256 portraitIdCount);

    /**
     * @notice Returns the portraitId a turbohost is registered to
     * @dev Mapping of nodeAddress => portraitId
     */
    function turboNodeAddressToPortraitId(
        address turboNodeAddress
    ) external view returns (uint256 portraitId);

    /**
     * @notice Returns the turbohost a portraitId is registered to
     * @dev Mapping of portraitId => turboNodeAddress
     */
    function portraitIdToTurboNodeAddress(
        uint256 portraitId
    ) external view returns (address turboNodeAddress);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @dev Error when a node address is already registered to a portraitId.
    error NodeAlreadyRegistered();

    /// @dev Error when a node address is not registered to a portraitId.
    error NodeNotRegistered();

    /// @dev Error when caller is not owner or delegate of portraitId.
    error Unauthorized();

    /// @dev Revert with `InvalidAddress` if caller attempts to perform an action with an invalid address
    error InvalidAddress();

    /// @dev Revert with `MaxNodesReached` if the maximum amount of nodes per portraitId has been reached.
    error MaxNodesReached();

    /// @dev Revert with `InvalidArrayLength` if the length of the array is invalid, e.g. empty.
    error InvalidArrayLength();

    /// @dev Error when signature is expired.
    error ExpiredSignature();

    /// @dev Error when signature is invalid.
    error InvalidSignature();

    /// @dev Error when the node is already registered as a turbohost.
    error TurbohostAlreadyRegistered();

    /// @dev Error when the node is not registered as a turbohost.
    error TurbohostNotRegistered();

    /// @dev Error when the node is a normal node and not a turbohost.
    error IsNormalNode();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Emit an event when a node is registered.
     *
     * @param nodeAddress The address of the node that was registered.
     * @param portraitId The portraitId that was registered to the node.
     * @param timestamp The timestamp of the registration.
     */
    event NodeRegistered(
        address indexed nodeAddress,
        uint256 indexed portraitId,
        uint256 indexed timestamp
    );

    /**
     * @dev Emit an event when a node is unregistered.
     *
     * @param nodeAddress The address of the node that was unregistered.
     * @param portraitId The portraitId that was unregistered from the node.
     * @param timestamp The timestamp of the unregistration.
     */
    event NodeUnregistered(
        address indexed nodeAddress,
        uint256 indexed portraitId,
        uint256 indexed timestamp
    );

    /**
     * @dev Emit an event when maxNodesPerPortraitId is updated.
     *
     * @param maxNodes The new maximum amount of nodes that can be registered for a portraitId.
     * @param timestamp The timestamp of the update.
     */
    event MaxNodesPerPortraitIdUpdated(
        uint256 indexed maxNodes,
        uint256 indexed timestamp
    );

    /**
     * @dev Emit an event when the status of a turbohost is updated.
     *
     * @param nodeAddress The address of the node that was updated.
     * @param isTurbohost  The new status of the node as bool.
     * @param timestamp  The timestamp of the update.
     */
    event TurbohostUpdated(
        address indexed nodeAddress,
        bool indexed isTurbohost,
        uint256 indexed timestamp
    );

    /*//////////////////////////////////////////////////////////////
                         NODE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Registers a node to a portraitId.
     * @dev Can only be called by the owner or delegate of the portraitId.
     *
     * @param nodeAddress The address of the node to register.
     * @param portraitId The portraitId to register the node to.
     * @param deadline The deadline of the signature.
     * @param sig EIP-6492 signature signed by the node address.
     */
    function registerNodeToPortraitId(
        address nodeAddress,
        uint256 portraitId,
        uint256 deadline,
        bytes calldata sig
    ) external;

    /**
     * @notice Unregisters a node from a portraitId.
     * @dev Can only be called by the owner or delegate of the portraitId.
     *
     * @param nodeAddress The address of the node to unregister.
     * @param portraitId The portraitId to unregister the node from.
     */
    function unregisterNodeFromPortraitId(
        address nodeAddress,
        uint256 portraitId
    ) external;

    /**
     * @notice Unregisters a node from all portraitIds.
     * @dev This function is useful when a node wants to unregister from all portraitIds.
     *      We don't keep track of all portraitIds a node is registered to, so the user must provide the portraitIds.
     *      There is a simple check if there are enough portraitIds.
     *
     *
     * @param nodeAddress The address of the node to unregister.
     * @param portraitIds All the portraitIds registered to the node.
     */
    function unregisterNodeFromAllPortraitIds(
        address nodeAddress,
        uint256[] calldata portraitIds
    ) external;

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Verify a signature for registering a node to a portraitId.
     * @dev This signature logic is different than other Portrait contracts,
     *      as it uses a bytes32(portraitId) hash.
     *
     * @param signer The node address that signed the message.
     * @param portraitId The portraitId to register the node to.
     * @param deadline Expiration timestamp of the signature.
     * @param sig      EIP-6492 signature signed by the node address/signer.
     */
    function verifyRegisterNodeToPortraitIdProof(
        address signer,
        uint256 portraitId,
        uint256 deadline,
        bytes calldata sig
    ) external returns (bool isValid);

    /*//////////////////////////////////////////////////////////////
                         VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether a node is registered to a portraitId.
     * @dev A node is registered if the nodeAddress is in the portraitIdToNodeAddresses mapping.
     *
     * @param nodeAddress The address of the node to check.
     * @param portraitId The portraitId to check.
     *
     * @return hasRegistered True if the node is registered to the portraitId, false otherwise.
     */
    function hasRegisteredNode(
        address nodeAddress,
        uint256 portraitId
    ) external view returns (bool hasRegistered);

    /**
     * @notice Returns whether a portraitId is a turbohost.
     *
     * @param portraitId The portraitId to check.
     *
     * @return isTurbohost True if the node is registered as a turbohost, false otherwise.
     */
    function isPortraitIdTurbohost(
        uint256 portraitId
    ) external view returns (bool isTurbohost);

    /**
     * @notice Returns whether a node is a turbohost.
     *
     * @param nodeAddress The address of the node to check.
     *
     * @return isTurbohost True if the node is registered as a turbohost, false otherwise.
     */
    function isNodeAddressTurbohost(
        address nodeAddress
    ) external view returns (bool isTurbohost);

    /*//////////////////////////////////////////////////////////////
                         PERMISSIONED ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the maximum amount of nodes that can be registered for a portraitId.
     *  @dev Can only be called by the owner of the contract.
     *
     * @param maxNodes The maximum amount of nodes that can be registered for a portraitId.
     */
    function setMaxNodesPerPortraitId(uint256 maxNodes) external;

    /**
     * @notice Sets a node as a turbohost for a portraitId and nodeAddress.
     * @dev Can only be called by the owner of the contract.
     *
     * @param nodeAddress The address of the node to set as a turbohost.
     * @param portraitId The portraitId to set the node as a turbohost.
     * @param isTurbohost True if the node should be a turbohost, false otherwise.
     */
    function setTurbohostForNode(
        address nodeAddress,
        uint256 portraitId,
        bool isTurbohost
    ) external;

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetches the latest contract addresses from the PortraitContractRegistry contract and updates the state variables.
     * @dev May be called by anyone, as the state variables of the contract addresses in PortraitContractRegistry are only updatable by the owner.
     */
    function updateProtocolContracts() external;
}
