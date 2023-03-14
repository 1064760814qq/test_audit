// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC721 {
  function transferFrom(address _from, address _to, uint256 _tokenId) external;
  function safeTransferFrom(address _from, address _to, uint256 _tokenId, string memory txType) external;
  function safeTransferFrom(address _from, address _to, uint256 _tokenId, uint256 _value, bytes calldata _data,string memory txType) external;
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
  function balanceOf(address _owner) external view returns (uint256);
  function ownerOf(uint256 _tokenId) external view returns (address);
  function setApprovalForAll(address operator, bool approved) external;
  function tokenRoyalty(uint256 _id) external view returns (uint256);
  function isApprovedForAll(address owner, address operator) external view returns (bool);
}