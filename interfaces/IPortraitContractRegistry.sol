// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPortraitIdRegistry} from "./IPortraitIdRegistry.sol";
import {IPortraitAccessRegistry} from "./IPortraitAccessRegistry.sol";
import {IPortraitPlanRegistry} from "./IPortraitPlanRegistry.sol";
import {IPortraitNameRegistry} from "./IPortraitNameRegistry.sol";
import {IPortraitStateRegistry} from "./IPortraitStateRegistry.sol";
import {IPortraitNodeRegistry} from "./IPortraitNodeRegistry.sol";
import {PortraitSigValidator} from "../../lib/PortraitSigValidator.sol";

interface IPortraitContractRegistry {
    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the PortraitIdRegistry contract
     */
    function portraitIdRegistry()
        external
        view
        returns (IPortraitIdRegistry portraitIdRegistry);

    /**
     * @notice Returns the address of the PortraitAccessRegistry contract
     */
    function portraitAccessRegistry()
        external
        view
        returns (IPortraitAccessRegistry portraitAccessRegistry);

    /**
     * @notice Returns the address of the PortraitPlanRegistry contract
     */
    function portraitPlanRegistry()
        external
        view
        returns (IPortraitPlanRegistry portraitPlanRegistry);

    /**
     * @notice Returns the address of the PortraitNameRegistry contract
     */
    function portraitNameRegistry()
        external
        view
        returns (IPortraitNameRegistry portraitNameRegistry);

    /**
     * @notice Returns the address of the PortraitStateRegistry contract
     */
    function portraitStateRegistry()
        external
        view
        returns (IPortraitStateRegistry portraitStateRegistry);

    /**
     * @notice Returns the address of the PortraitNodeRegistry contract
     */
    function portraitNodeRegistry()
        external
        view
        returns (IPortraitNodeRegistry portraitNodeRegistry);

    /**
     * @notice Returns the address of the PortraitSigValidator contract
     */
    function portraitSigValidator()
        external
        view
        returns (PortraitSigValidator portraitSigValidator);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted event when the external contracts are updated
     * @dev Listen for this event to update your local contract instances
     *
     * @param caller The caller of the function, which should be the owner of the contract.
     * @param timestamp The timestamp of the update.
     */
    event ExternalContractsUpdated(
        address indexed caller,
        uint256 indexed timestamp
    );

    /*//////////////////////////////////////////////////////////////
                                UPDATE ACTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the contract addresses for the external contracts used by the protocol.
     * @dev This function is accessible exclusively to the contract owner to update essential contract references.
     *      The UniversalSigValidator contract, compliant with ERC-6492, enables signature verification for predeployed contracts.
     *
     *      ERC-6492 introduces a standardized method for verifying signatures of counterfactual contracts
     *      before their deployment, extending the ERC-1271 standard.
     *
     *      More details on ERC-6492: https://eips.ethereum.org/EIPS/eip-6492
     *
     * @param portraitIdRegistryAddress The address of the PortraitIdRegistry contract complying with the IPortraitIdRegistry interface.
     * @param portraitAccessRegistryAddress The address of the PortraitAccessRegistry contract adhering to the IPortraitAccessRegistry interface.
     * @param portraitPlanRegistryAddress The address of the PortraitPlanRegistry contract as per the IPortraitPlanRegistry interface.
     * @param portraitNameRegistryAddress The address of the PortraitNameRegistry contract respecting the IPortraitNameRegistry interface.
     * @param portraitStateRegistryAddress The address of the PortraitStateRegistry contract implementing the IPortraitStateRegistry interface.
     * @param portraitNodeRegistryAddress The address of the PortraitNodeRegistry contract following the IPortraitNodeRegistry interface.
     * @param portraitSigValidator The address of the PortraitSigValidator contract.
     */
    function updateProtocolContracts(
        address portraitIdRegistryAddress,
        address portraitAccessRegistryAddress,
        address portraitPlanRegistryAddress,
        address portraitNameRegistryAddress,
        address portraitStateRegistryAddress,
        address portraitNodeRegistryAddress,
        address portraitSigValidator
    ) external;

    /**
     * @notice Updates the state variables in all external contracts used by the external contracts.
     * @dev This function is accessible exclusively to the contract owner to update essential contract references from the external contracts.
     *      The behavior of this function is different from updateProtocolContracts, which updates the contract addresses in this contract.
     *      This function updates the state variables of the external contracts.
     */
    function updateAllExternalContracts() external;
}
