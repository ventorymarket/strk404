use starknet::ContractAddress;

const IERC404_ID: felt252 = 0x35a079abca3b676315532825fb5194cea63018b0fec76211980e5e68cf1d96a;
const IERC404_METADATA_ID: felt252 =
    0x3073fd59d1417f1c144b6ac084101257077a15d87ab92d3b99ead1725138774;
const IERC404_ADMIN_ID: felt252 = 0x79723b35245ab4d61c5168fe0446b21c61e96420d4938917e47dcdcca3a136;
const IERC721_RECEIVER_ID: felt252 =
    0x3a0dff5f70d80458ad14ae37bb182a728e3c8cdda0402a5daa86620bdf910bc;

#[starknet::interface]
trait IERC404<TState> {
    fn total_supply(self: @TState) -> u256;
    fn erc20_total_supply(self: @TState) -> u256;
    fn erc721_total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn erc20_balance_of(self: @TState, account: ContractAddress) -> u256;
    fn erc721_balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, from: ContractAddress, to: ContractAddress, amount_or_id: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount_or_id: u256) -> bool;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, data: Span<felt252>
    );
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn get_owned(self: @TState, owner: ContractAddress, index: u32) -> u256;
    fn get_owned_index(self: @TState, token_id: u256) -> u32;
    fn get_minted(self: @TState) -> u256;
    fn increase_allowance(ref self: TState, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(ref self: TState, spender: ContractAddress, subtracted_value: u256);
}

#[starknet::interface]
trait IERC404Metadata<TState> {
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn units(self: @TState) -> u256;
}

#[starknet::interface]
trait IERC404Admin<TState> {
    fn set_whitelist(ref self: TState, target: ContractAddress, state: bool);
    fn is_whitelist(self: @TState, address: ContractAddress) -> bool;
    fn owner(self: @TState) -> ContractAddress;
}

#[starknet::interface]
trait IERC404Camel<TState> {
    fn totalSupply(self: @TState) -> u256;
    fn erc20TotalSupply(self: @TState) -> u256;
    fn erc721TotalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn erc20BalanceOf(self: @TState, account: ContractAddress) -> u256;
    fn erc721BalanceOf(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, to: ContractAddress, amount: u256) -> bool;
    fn safeTransferFrom(
        ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, data: Span<felt252>
    );
    fn transferFrom(
        ref self: TState, from: ContractAddress, to: ContractAddress, amountOrId: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amountOrId: u256) -> bool;
    fn ownerOf(self: @TState, tokenId: u256) -> ContractAddress;
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @TState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;
    fn getOwned(self: @TState, owner: ContractAddress, index: u32) -> u256;
    fn getOwnedIndex(self: @TState, tokenId: u256) -> u32;
    fn getMinted(self: @TState) -> u256;
    fn increaseAllowance(ref self: TState, spender: ContractAddress, addedValue: u256);
    fn decreaseAllowance(ref self: TState, spender: ContractAddress, subtractedValue: u256);
}

#[starknet::interface]
trait IERC404CamelOnly<TState> {
    fn totalSupply(self: @TState) -> u256;
    fn erc20TotalSupply(self: @TState) -> u256;
    fn erc721TotalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn erc20BalanceOf(self: @TState, account: ContractAddress) -> u256;
    fn erc721BalanceOf(self: @TState, account: ContractAddress) -> u256;
    fn safeTransferFrom(
        ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, data: Span<felt252>
    );
    fn transferFrom(
        ref self: TState, from: ContractAddress, to: ContractAddress, amountOrId: u256
    ) -> bool;
    fn ownerOf(self: @TState, tokenId: u256) -> ContractAddress;
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @TState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;
    fn getOwned(self: @TState, owner: ContractAddress, index: u32) -> u256;
    fn getOwnedIndex(self: @TState, tokenId: u256) -> u32;
    fn getMinted(self: @TState) -> u256;
    fn increaseAllowance(ref self: TState, spender: ContractAddress, addedValue: u256);
    fn decreaseAllowance(ref self: TState, spender: ContractAddress, subtractedValue: u256);
}

#[starknet::interface]
trait IERC404AdminCamelOnly<TState> {
    fn setWhitelist(ref self: TState, target: ContractAddress, state: bool);
    fn isWhitelist(self: @TState, address: ContractAddress) -> bool;
}

#[starknet::interface]
trait ERC404ABI<TState> {
    // IERC404
    fn total_supply(self: @TState) -> u256;
    fn erc20_total_supply(self: @TState) -> u256;
    fn erc721_total_supply(self: @TState) -> u256;
    fn balance_of(self: @TState, account: ContractAddress) -> u256;
    fn erc20_balance_of(self: @TState, account: ContractAddress) -> u256;
    fn erc721_balance_of(self: @TState, account: ContractAddress) -> u256;
    fn allowance(self: @TState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TState, from: ContractAddress, to: ContractAddress, amount_or_id: u256
    ) -> bool;
    fn approve(ref self: TState, spender: ContractAddress, amount_or_id: u256) -> bool;
    fn owner_of(self: @TState, token_id: u256) -> ContractAddress;
    fn safe_transfer_from(
        ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, data: Span<felt252>
    );
    fn set_approval_for_all(ref self: TState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn get_owned(self: @TState, owner: ContractAddress, index: u32) -> u256;
    fn get_owned_index(self: @TState, token_id: u256) -> u32;
    fn get_minted(self: @TState) -> u256;
    fn increase_allowance(ref self: TState, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(ref self: TState, spender: ContractAddress, subtracted_value: u256);

    // IERC404Metadata
    fn name(self: @TState) -> felt252;
    fn symbol(self: @TState) -> felt252;
    fn decimals(self: @TState) -> u8;
    fn units(self: @TState) -> u256;

    // IERC404Admin
    fn set_whitelist(ref self: TState, target: ContractAddress, state: bool);
    fn is_whitelist(self: @TState, address: ContractAddress) -> bool;
    fn owner(self: @TState) -> ContractAddress;

    // ISRC5
    fn supports_interface(self: @TState, interface_id: felt252) -> bool;

    // IERC404CamelOnly
    fn totalSupply(self: @TState) -> u256;
    fn erc20TotalSupply(self: @TState) -> u256;
    fn erc721TotalSupply(self: @TState) -> u256;
    fn balanceOf(self: @TState, account: ContractAddress) -> u256;
    fn erc20BalanceOf(self: @TState, account: ContractAddress) -> u256;
    fn erc721BalanceOf(self: @TState, account: ContractAddress) -> u256;
    fn safeTransferFrom(
        ref self: TState, from: ContractAddress, to: ContractAddress, id: u256, data: Span<felt252>
    );
    fn transferFrom(
        ref self: TState, from: ContractAddress, to: ContractAddress, amountOrId: u256
    ) -> bool;
    fn ownerOf(self: @TState, tokenId: u256) -> ContractAddress;
    fn setApprovalForAll(ref self: TState, operator: ContractAddress, approved: bool);
    fn getApproved(self: @TState, tokenId: u256) -> ContractAddress;
    fn isApprovedForAll(self: @TState, owner: ContractAddress, operator: ContractAddress) -> bool;
    fn getOwned(self: @TState, owner: ContractAddress, index: u32) -> u256;
    fn getOwnedIndex(self: @TState, tokenId: u256) -> u32;
    fn getMinted(self: @TState) -> u256;
    fn increaseAllowance(ref self: TState, spender: ContractAddress, addedValue: u256);
    fn decreaseAllowance(ref self: TState, spender: ContractAddress, subtractedValue: u256);

    // IERC404AdminCamelOnly
    fn setWhitelist(ref self: TState, target: ContractAddress, state: bool);
    fn isWhitelist(self: @TState, address: ContractAddress) -> bool;

    // ISRC5Camel
    fn supportsInterface(self: @TState, interfaceId: felt252) -> bool;
}

#[starknet::interface]
trait IERC721Receiver<TState> {
    fn on_erc721_received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> felt252;
}

#[starknet::interface]
trait IERC721ReceiverCamel<TState> {
    fn onERC721Received(
        self: @TState,
        operator: ContractAddress,
        from: ContractAddress,
        tokenId: u256,
        data: Span<felt252>
    ) -> felt252;
}
