// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../interfaces/l2/IPortraitContractRegistry.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact ryan@portrait.gg
contract PortraitContractRegistry is
    IPortraitContractRegistry,
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    IPortraitIdRegistry public portraitIdRegistry;

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    IPortraitAccessRegistry public portraitAccessRegistry;

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    IPortraitPlanRegistry public portraitPlanRegistry;

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    IPortraitNameRegistry public portraitNameRegistry;

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    IPortraitStateRegistry public portraitStateRegistry;

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    IPortraitNodeRegistry public portraitNodeRegistry;

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    PortraitSigValidator public portraitSigValidator;

    /*//////////////////////////////////////////////////////////////
                                UPDATE LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    function updateProtocolContracts(
        address portraitIdRegistryAddress,
        address portraitAccessRegistryAddress,
        address portraitPlanRegistryAddress,
        address portraitNameRegistryAddress,
        address portraitStateRegistryAddress,
        address portraitNodeRegistryAddress,
        address portraitSigValidatorAddress
    ) external onlyOwner {
        portraitIdRegistry = IPortraitIdRegistry(portraitIdRegistryAddress);

        portraitAccessRegistry = IPortraitAccessRegistry(
            portraitAccessRegistryAddress
        );
        portraitPlanRegistry = IPortraitPlanRegistry(
            portraitPlanRegistryAddress
        );
        portraitNameRegistry = IPortraitNameRegistry(
            portraitNameRegistryAddress
        );
        portraitStateRegistry = IPortraitStateRegistry(
            portraitStateRegistryAddress
        );
        portraitNodeRegistry = IPortraitNodeRegistry(
            portraitNodeRegistryAddress
        );
        portraitSigValidator = PortraitSigValidator(
            portraitSigValidatorAddress
        );

        _updateAllExternalContracts();

        emit ExternalContractsUpdated(msg.sender, block.timestamp);
    }

    /**
     * @inheritdoc IPortraitContractRegistry
     */
    function updateAllExternalContracts() external onlyOwner {
        _updateAllExternalContracts();
    }

    function _updateAllExternalContracts() internal {
        portraitIdRegistry.updateProtocolContracts();
        portraitAccessRegistry.updateProtocolContracts();
        portraitPlanRegistry.updateProtocolContracts();
        portraitNameRegistry.updateProtocolContracts();
        portraitStateRegistry.updateProtocolContracts();
        portraitNodeRegistry.updateProtocolContracts();
    }

    /*//////////////////////////////////////////////////////////////
                                OPENZEPPELIN
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
