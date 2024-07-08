// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../../interfaces/l2/IPortraitStateRegistry.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:security-contact ryan@portrait.gg
contract PortraitStateRegistry is
    IPortraitStateRegistry,
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /*//////////////////////////////////////////////////////////////
                                 VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitStateRegistry
     */
    IPortraitContractRegistry public portraitContractRegistry;

    /**
     * @inheritdoc IPortraitStateRegistry
     */
    IPortraitIdRegistry public portraitIdRegistry;

    /**
     * @inheritdoc IPortraitStateRegistry
     */
    IPortraitAccessRegistry public portraitAccessRegistry;

    /**
     * @inheritdoc IPortraitStateRegistry
     */
    IPortraitPlanRegistry public portraitPlanRegistry;

    /*//////////////////////////////////////////////////////////////
                                 MAPPINGS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitStateRegistry
     */
    mapping(uint256 => string) public portraitIdToPortraitHash;

    function setPortraitState(
        uint256 portraitIdToSet,
        uint256 portraitIdFromSender,
        string memory portraitHash
    ) external whenNotPaused {
        bool hasAuthorityToActOnBehalfOfPortraitIdFromSender = portraitAccessRegistry
                .isDelegateOrOwnerOfPortraitId(
                    portraitIdFromSender,
                    msg.sender
                );

        if (!hasAuthorityToActOnBehalfOfPortraitIdFromSender)
            revert Unauthorized();

        bool isDelegateOrOwnerOfPortraitIdToSet = portraitAccessRegistry
            .isDelegateOrOwnerOfPortraitId(portraitIdToSet, msg.sender);

        if (!isDelegateOrOwnerOfPortraitIdToSet) {
            bool isTeamPlan = portraitPlanRegistry.isTeamPlan(portraitIdToSet);

            if (!isTeamPlan) {
                revert Unauthorized();
            }

            uint256 roleOfPortraitIdFromSender = uint256(
                portraitPlanRegistry.getTeamRoleForPortraitId(
                    portraitIdFromSender,
                    portraitIdToSet
                )
            );

            // At least editor
            if (roleOfPortraitIdFromSender >= 1) {
                revert Unauthorized();
            }
        }

        _setPortraitState(portraitIdToSet, portraitIdFromSender, portraitHash);
    }

    function _setPortraitState(
        uint256 portraitIdToSet,
        uint256 portraitIdFromSender,
        string memory portraitHash
    ) internal {
        if (
            keccak256(bytes(portraitHash)) ==
            keccak256(bytes(portraitIdToPortraitHash[portraitIdToSet]))
        ) {
            revert DuplicateState();
        }

        portraitIdToPortraitHash[portraitIdToSet] = portraitHash;

        emit PortraitStateUpdated(
            portraitIdToSet,
            portraitHash,
            portraitIdFromSender
        );
    }

    /*//////////////////////////////////////////////////////////////
                            PROTOCOL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IPortraitStateRegistry
     */
    function updateProtocolContracts() external {
        portraitIdRegistry = portraitContractRegistry.portraitIdRegistry();
        portraitAccessRegistry = portraitContractRegistry
            .portraitAccessRegistry();
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

        _pause();

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

        if (portraitAccessRegistry == IPortraitAccessRegistry(address(0))) {
            bool hasAccessRegistry = portraitContractRegistry
                .portraitAccessRegistry() !=
                IPortraitAccessRegistry(address(0));

            if (hasAccessRegistry) {
                portraitAccessRegistry = portraitContractRegistry
                    .portraitAccessRegistry();
            }
        }

        if (portraitPlanRegistry == IPortraitPlanRegistry(address(0))) {
            bool hasPlanRegistry = portraitContractRegistry
                .portraitPlanRegistry() != IPortraitPlanRegistry(address(0));

            if (hasPlanRegistry) {
                portraitPlanRegistry = portraitContractRegistry
                    .portraitPlanRegistry();
            }
        }
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
