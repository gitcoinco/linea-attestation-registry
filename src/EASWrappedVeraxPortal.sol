// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/security/PausableUpgradeable.sol";

import { AbstractPortal } from "./interface/AbstractPortal.sol";
import { AttestationPayload, Attestation as VeraxAttestation } from "./types/Structs.sol";
import { Attestation, AttestationRequest, DelegatedAttestationRequest, DelegatedRevocationRequest, ISchemaRegistry, IEAS, MultiAttestationRequest, MultiDelegatedAttestationRequest, MultiDelegatedRevocationRequest, MultiRevocationRequest, RevocationRequest } from "eas-contracts/contracts/IEAS.sol";

/**
 * @title EASWrappedVeraxPortal
 * @notice This is a Verax Portal that interfaces as if it is a (limited) EAS registry
 */
contract EASWrappedVeraxPortal is UUPSUpgradeable, OwnableUpgradeable, IEAS, PausableUpgradeable, AbstractPortal {
  mapping(address user => mapping(bytes32 schema => bytes32)) public userAttestations;

  error NotImplemented();

  address public attesterAddress;

  error OnlyAttester();

  function initialize(address[] calldata _modules, address _router) public override initializer {
    __Ownable_init();
    AbstractPortal.initialize(_modules, _router);
  }

  modifier onlyAttester() {
    if (msg.sender != attesterAddress) {
      revert OnlyAttester();
    }
    _;
  }

  function supportsInterface(bytes4 interfaceID) public pure override returns (bool) {
    return (interfaceID == type(IEAS).interfaceId ||
      interfaceID == type(UUPSUpgradeable).interfaceId ||
      interfaceID == type(OwnableUpgradeable).interfaceId ||
      interfaceID == type(PausableUpgradeable).interfaceId ||
      AbstractPortal.supportsInterface(interfaceID));
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  // solhint-disable-next-line no-empty-blocks
  function _authorizeUpgrade(address) internal override onlyOwner {}

  function setAttesterAddress(address _attesterAddress) external onlyOwner {
    attesterAddress = _attesterAddress;
  }

  function multiAttest(
    MultiAttestationRequest[] memory multiAttestationRequests
  ) external payable override whenNotPaused onlyAttester returns (bytes32[] memory) {
    uint256 numAttestations = 0;
    for (uint256 i = 0; i < multiAttestationRequests.length; ) {
      unchecked {
        numAttestations += multiAttestationRequests[i].data.length;
        i++;
      }
    }

    AttestationPayload[] memory attestationsPayloads = new AttestationPayload[](numAttestations);
    bytes[][] memory validationPayloads = new bytes[][](numAttestations);

    uint32 attestationId = AbstractPortal.attestationRegistry.getAttestationIdCounter() + 1;
    bytes32[] memory attestationIds = new bytes32[](numAttestations);

    uint256 currentIndex = 0;
    for (uint256 i = 0; i < multiAttestationRequests.length; ) {
      for (uint256 j = 0; j < multiAttestationRequests[i].data.length; ) {
        address recipient = multiAttestationRequests[i].data[j].recipient;
        attestationsPayloads[currentIndex] = AttestationPayload(
          multiAttestationRequests[i].schema,
          multiAttestationRequests[i].data[j].expirationTime,
          abi.encodePacked(recipient),
          multiAttestationRequests[i].data[j].data
        );

        validationPayloads[currentIndex] = new bytes[](0);

        attestationIds[currentIndex] = bytes32(abi.encode(attestationId));

        userAttestations[recipient][multiAttestationRequests[i].schema] = attestationIds[currentIndex];

        unchecked {
          j++;
          currentIndex++;
          attestationId++;
        }
      }
      unchecked {
        i++;
      }
    }

    super.bulkAttest(attestationsPayloads, validationPayloads);

    return attestationIds;
  }

  function multiRevoke(
    MultiRevocationRequest[] calldata multiRevocationRequests
  ) external payable override whenNotPaused onlyAttester {
    uint256 numRevocations = 0;
    for (uint256 i = 0; i < multiRevocationRequests.length; ) {
      unchecked {
        numRevocations += multiRevocationRequests[i].data.length;
        i++;
      }
    }

    bytes32[] memory revokeIds = new bytes32[](numRevocations);
    bytes32[] memory replacedBy = new bytes32[](numRevocations);

    uint256 currentIndex = 0;
    for (uint256 i = 0; i < multiRevocationRequests.length; ) {
      for (uint256 j = 0; j < multiRevocationRequests[i].data.length; ) {
        revokeIds[currentIndex] = multiRevocationRequests[i].data[j].uid;

        // Pass an empty replacedBy to indicate that the attestation is revoked
        replacedBy[currentIndex] = "";

        address recipient = getAttestation(multiRevocationRequests[i].data[j].uid).recipient;
        userAttestations[recipient][multiRevocationRequests[i].schema] = 0;

        unchecked {
          j++;
          currentIndex++;
        }
      }

      unchecked {
        i++;
      }
    }

    super.bulkRevoke(revokeIds, replacedBy);
  }

  function getAttestation(bytes32 uid) public view returns (Attestation memory) {
    VeraxAttestation memory veraxAttestation = AbstractPortal.attestationRegistry.getAttestation(uid);

    Attestation memory convertedAttestation = Attestation(
      veraxAttestation.attestationId,
      veraxAttestation.schemaId,
      veraxAttestation.attestedDate,
      veraxAttestation.expirationDate,
      veraxAttestation.revocationDate,
      "",
      address(uint160(bytes20(veraxAttestation.subject))),
      veraxAttestation.attester,
      true,
      veraxAttestation.attestationData
    );

    return convertedAttestation;
  }

  // Unused Verax hooks
  // solhint-disable no-empty-blocks

  function _beforeAttest(AttestationPayload memory attestation, uint256 value) internal override {}

  function _afterAttest() internal override {}

  function _onRevoke(bytes32 attestationId, bytes32 replacedBy) internal override {}

  function _onBulkAttest(
    AttestationPayload[] memory attestationsPayloads,
    bytes[][] memory validationPayloads
  ) internal override {}

  function _onBulkRevoke(bytes32[] memory attestationIds, bytes32[] memory replacedBy) internal override {}

  // solhint-enable no-empty-blocks

  // !!! None of the following EAS functions are implemented !!!

  function attest(AttestationRequest calldata /* request */) external payable returns (bytes32) {
    revert NotImplemented();
  }

  function attestByDelegation(
    DelegatedAttestationRequest calldata /* delegatedRequest */
  ) external payable returns (bytes32) {
    revert NotImplemented();
  }

  function getRevokeOffchain(address /* revoker */, bytes32 /* data */) external pure returns (uint64) {
    revert NotImplemented();
  }

  function getSchemaRegistry() external pure returns (ISchemaRegistry) {
    revert NotImplemented();
  }

  function getTimestamp(bytes32 /* data */) external pure returns (uint64) {
    revert NotImplemented();
  }

  function isAttestationValid(bytes32 /* uid */) external pure returns (bool) {
    revert NotImplemented();
  }

  function multiAttestByDelegation(
    MultiDelegatedAttestationRequest[] calldata /* multiDelegatedRequest */
  ) external payable returns (bytes32[] memory) {
    revert NotImplemented();
  }

  function multiRevokeByDelegation(
    MultiDelegatedRevocationRequest[] calldata /* multiDelegatedRequests */
  ) external payable {
    revert NotImplemented();
  }

  function multiRevokeOffchain(bytes32[] calldata /* data */) external pure returns (uint64) {
    revert NotImplemented();
  }

  function multiTimestamp(bytes32[] calldata /* data */) external pure returns (uint64) {
    revert NotImplemented();
  }

  function revoke(RevocationRequest calldata /* request */) external payable {
    revert NotImplemented();
  }

  function revokeByDelegation(DelegatedRevocationRequest calldata /* delegatedRequest */) external payable {
    revert NotImplemented();
  }

  function revokeOffchain(bytes32 /* data */) external pure returns (uint64) {
    revert NotImplemented();
  }

  function timestamp(bytes32 /* data */) external pure returns (uint64) {
    revert NotImplemented();
  }
}
