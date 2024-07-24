#[starknet::component]
mod ERC404Component {
    use erc404::token::erc404::interface::IERC404;
    use alexandria_ascii::ToAsciiTrait;
    use alexandria_math::fast_power::fast_power;
    use alexandria_storage::list::{List, ListTrait};
    use core::Zeroable;
    use erc404::token::erc404::interface;
    use integer::BoundedInt;
    use openzeppelin::account;
    use openzeppelin::introspection::dual_src5::{DualCaseSRC5, DualCaseSRC5Trait};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::dual721_receiver::{
        DualCaseERC721Receiver, DualCaseERC721ReceiverTrait
    };
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {
        // Contract owner
        ERC404_owner: ContractAddress,
        // Token name
        ERC404_name: felt252,
        // Token symbol
        ERC404_symbol: felt252,
        // Decimals for fractional representation
        ERC404_decimals: u8,
        // Total ERC20 supply in fractionalized representation
        ERC404_ERC20_total_supply: u256,
        // Total ERC721 supply in native representation
        ERC404_ERC721_total_supply: u256,
        // Current mint counter, monotonically increasing to ensure accurate ownership
        ERC404_minted: u256,
        // Token ERC20 balance of user in fractional representation
        ERC404_ERC20_balances: LegacyMap<ContractAddress, u256>,
        // Token ERC721 balance of user in native representation
        ERC404_ERC721_balances: LegacyMap<ContractAddress, u256>,
        // Token allowance of user in fractional representation
        ERC404_allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
        // Address approved for NFT(tokenId - in native representation)
        ERC404_get_approved: LegacyMap<u256, ContractAddress>,
        // NFT approval for all in native representation
        ERC404_is_approved_for_all: LegacyMap<(ContractAddress, ContractAddress), bool>,
        // Owner of NFT(tokenId - in native representation)
        ERC404_owner_of: LegacyMap<u256, ContractAddress>,
        // Array of owner owned ids
        ERC404_owned: LegacyMap<ContractAddress, List<u256>>,
        // Tracks indices for the _owned mapping
        ERC404_owned_index: LegacyMap<u256, u32>,
        // Addresses whitelisted from minting/burning for gas savings (pairs, routers, etc)
        ERC404_whitelist: LegacyMap<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        NFTTransfer: NFTTransfer,
        NFTApproval: NFTApproval,
        NFTApprovalForAll: NFTApprovalForAll
    }

    /// Emitted when tokens are moved from address `from` to address `to`.
    #[derive(Drop, starknet::Event)]
    struct Transfer {
        // #[key]
        from: ContractAddress,
        // #[key]
        to: ContractAddress,
        value: u256
    }

    /// Emitted when the allowance of a `spender` for an `owner` is set by a call
    /// to `approve`. `value` is the new allowance.
    #[derive(Drop, starknet::Event)]
    struct Approval {
        // #[key]
        owner: ContractAddress,
        // #[key]
        spender: ContractAddress,
        value: u256
    }

    /// Emitted when `token_id` token is transferred from `from` to `to`.
    #[derive(Drop, starknet::Event)]
    struct NFTTransfer {
        // #[key]
        from: ContractAddress,
        // #[key]
        to: ContractAddress,
        // #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables `approved` to manage the `token_id` token.
    #[derive(Drop, starknet::Event)]
    struct NFTApproval {
        // #[key]
        owner: ContractAddress,
        // #[key]
        approved: ContractAddress,
        // #[key]
        token_id: u256
    }

    /// Emitted when `owner` enables or disables (`approved`) `operator` to manage
    /// all of its assets.
    #[derive(Drop, starknet::Event)]
    struct NFTApprovalForAll {
        // #[key]
        owner: ContractAddress,
        // #[key]
        operator: ContractAddress,
        approved: bool
    }

    mod Errors {
        const NOT_OWNER: felt252 = 'ERC404: not owner';
        const APPROVE_FROM_ZERO: felt252 = 'ERC404: approve from 0';
        const APPROVE_TO_ZERO: felt252 = 'ERC404: approve to 0';
        const TRANSFER_FROM_ZERO: felt252 = 'ERC404: transfer from 0';
        const TRANSFER_TO_ZERO: felt252 = 'ERC404: transfer to 0';
        const BURN_FROM_ZERO: felt252 = 'ERC404: burn from 0';
        const MINT_TO_ZERO: felt252 = 'ERC404: mint to 0';
        const INVALID_TOKEN_ID: felt252 = 'ERC404: invalid token ID';
        const INVALID_RECEIVER: felt252 = 'ERC404: invalid receiver';
        const INVALID_SENDER: felt252 = 'ERC404: invalid sender';
        const ALREADY_MINTED: felt252 = 'ERC404: token already minted';
        const UNAUTHORIZED: felt252 = 'ERC404: unauthorized caller';
        const SELF_APPROVAL: felt252 = 'ERC404: self approval';
        const NOT_ENOUGH_ERC20_BALANCES: felt252 = 'ERC404: not enough erc20 bal';
        const NOT_ENOUGH_ERC721_BALANCES: felt252 = 'ERC404: not enough erc721 bal';
        const NOT_ENOUGH_ALLOWANCE: felt252 = 'ERC404: not enough allowance';
        const CALLER_MUST_NOT_BE_FROM: felt252 = 'ERC404: caller must not be from';
        const EXCEEDS_CUR_ALLOWANCES: felt252 = 'ERC404: exceeds cur allowances';
        const SAFE_TRANSFER_FAILED: felt252 = 'ERC721: safe transfer failed';
    }

    //
    // External
    //

    #[embeddable_as(ERC404Impl)]
    impl ERC404<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC404<ComponentState<TContractState>> {
        /// Returns the value of tokens in existence.
        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            self.ERC404_ERC20_total_supply.read()
        }

        /// Returns the value of tokens in existence.
        fn erc20_total_supply(self: @ComponentState<TContractState>) -> u256 {
            self.ERC404_ERC20_total_supply.read()
        }

        /// Returns the value of nfts in existence.
        fn erc721_total_supply(self: @ComponentState<TContractState>) -> u256 {
            self.ERC404_ERC721_total_supply.read()
        }

        /// Returns the amount of tokens owned by `account`.
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.ERC404_ERC20_balances.read(account)
        }

        /// Returns the amount of tokens owned by `account`.
        fn erc20_balance_of(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            self.ERC404_ERC20_balances.read(account)
        }

        fn erc721_balance_of(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            self.ERC404_ERC721_balances.read(account)
        }

        /// Returns the remaining number of tokens that `spender` is
        /// allowed to spend on behalf of `owner` through `transfer_from`.
        /// This is zero by default.
        /// This value changes when `approve` or `transfer_from` are called.
        fn allowance(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress
        ) -> u256 {
            self.ERC404_allowances.read((owner, spender))
        }

        /// Moves `amount` tokens from the caller's token balance to `to` and mint/burn nft if satisfied.
        ///
        /// Requirements:
        ///
        /// - `to` is not the zero address.
        /// - The caller has a balance of at least `amount`.
        ///
        /// Emits a `Transfer` event.
        fn transfer(
            ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256
        ) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, to, amount);
            true
        }

        /// Function for mixed transfers.
        /// This function assumes id / native if amount less than or equal to current max id.
        ///
        /// Requirements:
        ///
        /// - `from` is not the zero address.
        /// - `from` must have a balance of at least `amount`.
        /// - `to` is not the zero address.
        ///
        /// Emits a `Transfer & NFTTransfer` event.
        fn transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount_or_id: u256
        ) -> bool {
            let caller = get_caller_address();

            if (amount_or_id <= self.ERC404_minted.read() && amount_or_id > 0) {
                let uint: u256 = self.units();

                assert(
                    self.ERC404_owner_of.read(amount_or_id).is_non_zero(), Errors::INVALID_TOKEN_ID
                );
                assert(from == self.ERC404_owner_of.read(amount_or_id), Errors::INVALID_SENDER);
                assert(to.is_non_zero(), Errors::INVALID_RECEIVER);
                assert(
                    caller == from
                        || self.ERC404_is_approved_for_all.read((from, caller))
                        || caller == self.get_approved(amount_or_id),
                    Errors::UNAUTHORIZED
                );

                // Check balances
                assert(
                    self.ERC404_ERC20_balances.read(from) >= uint, Errors::NOT_ENOUGH_ERC20_BALANCES
                );
                assert(
                    self.ERC404_ERC721_balances.read(from) >= 1, Errors::NOT_ENOUGH_ERC721_BALANCES
                );

                // Write ERC20 balances
                self
                    .ERC404_ERC20_balances
                    .write(from, self.ERC404_ERC20_balances.read(from) - uint);
                self.ERC404_ERC20_balances.write(to, self.ERC404_ERC20_balances.read(to) + uint);

                // Write ERC721 balances
                self.ERC404_ERC721_balances.write(from, self.ERC404_ERC721_balances.read(from) - 1);
                self.ERC404_ERC721_balances.write(to, self.ERC404_ERC721_balances.read(to) + 1);

                self.ERC404_owner_of.write(amount_or_id, to);
                self.ERC404_get_approved.write(amount_or_id, Zeroable::zero());

                // Update owned for sender
                let updatedId: u256 = self
                    .ERC404_owned
                    .read(from)[self
                    .ERC404_owned
                    .read(from)
                    .len()
                    - 1]; // Last id sender owned
                let mut curSenderIds = self.ERC404_owned.read(from); // Current sender's owned ids
                let _ = curSenderIds
                    .set(
                        self.ERC404_owned_index.read(amount_or_id), updatedId
                    ); // Write the last id sender owned to `amountOrId`
                let _ = curSenderIds.pop_front(); // Pop
                self.ERC404_owned.write(from, curSenderIds);

                // Update index to the moved id (last id sender owned)
                self
                    .ERC404_owned_index
                    .write(updatedId, self.ERC404_owned_index.read(amount_or_id));

                // Push token to recipient
                let mut curRecipientIds = self.ERC404_owned.read(to);
                let _ = curRecipientIds.append(amount_or_id);
                self.ERC404_owned.write(to, curRecipientIds);

                // Update index for to owned
                self.ERC404_owned_index.write(amount_or_id, self.ERC404_owned.read(to).len() - 1);

                self.emit(NFTTransfer { from, to, token_id: amount_or_id });
                self.emit(Transfer { from, to, value: uint });

                true
            } else {
                assert(caller != from, Errors::CALLER_MUST_NOT_BE_FROM);
                let allowed = self.ERC404_allowances.read((from, caller));

                assert(allowed >= amount_or_id, Errors::NOT_ENOUGH_ALLOWANCE);

                if (allowed != BoundedInt::max()) {
                    self.ERC404_allowances.write((from, caller), allowed - amount_or_id);
                }

                self._transfer(from, to, amount_or_id);

                true
            }
        }

        /// Function for token approvals.
        /// This function assumes id / native if amount less than or equal to the current max id
        ///
        /// Requirements:
        ///
        /// - `spender` is not the zero address.
        ///
        /// Emits an `Approval || NFTApproval` event.
        fn approve(
            ref self: ComponentState<TContractState>, spender: ContractAddress, amount_or_id: u256
        ) -> bool {
            let caller = get_caller_address();

            assert(caller.is_non_zero(), Errors::APPROVE_FROM_ZERO);
            assert(spender.is_non_zero(), Errors::APPROVE_TO_ZERO);

            if (amount_or_id <= self.ERC404_minted.read() && amount_or_id > 0) {
                let owner = self.ERC404_owner_of.read(amount_or_id);

                assert(
                    caller == owner
                        || self.ERC404_is_approved_for_all.read((owner, caller))
                        || caller == self.get_approved(amount_or_id),
                    Errors::UNAUTHORIZED
                );

                self.ERC404_get_approved.write(amount_or_id, spender);

                self.emit(NFTApproval { owner: caller, approved: spender, token_id: amount_or_id });
            } else {
                self.ERC404_allowances.write((caller, spender), amount_or_id);
                self.emit(Approval { owner: caller, spender, value: amount_or_id });
            }

            true
        }

        /// Returns the owner address of `token_id`.
        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            let owner = self.ERC404_owner_of.read(token_id);
            match owner.is_zero() {
                bool::False(()) => owner,
                bool::True(()) => panic_with_felt252(Errors::INVALID_TOKEN_ID)
            }
        }

        /// Transfers ownership of `token_id` from `from` if `to` is either an account or `IERC721Receiver`.
        ///
        /// `data` is additional data, it has no specified format and it is sent in call to `to`.
        ///
        /// Requirements:
        ///
        /// - Caller is either approved or the `token_id` owner.
        /// - `to` is not the zero address.
        /// - `from` is not the zero address.
        /// - `token_id` exists.
        /// - `to` is either an account contract or supports the `IERC721Receiver` interface.
        ///
        /// Emits a `Transfer & NFTTransfer` event.
        fn safe_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            id: u256,
            data: Span<felt252>
        ) {
            if (id <= self.ERC404_minted.read() && id > 0) {
                let caller = get_caller_address();

                let owner = self.ERC404_owner_of.read(id);

                assert(
                    caller == owner
                        || self.ERC404_is_approved_for_all.read((owner, caller))
                        || caller == self.get_approved(id),
                    Errors::UNAUTHORIZED
                );

                assert(_check_on_erc721_received(from, to, id, data), Errors::SAFE_TRANSFER_FAILED);
            }

            self.transfer_from(from, to, id);
        }

        /// Enable or disable approval for `operator` to manage all of the
        /// caller's assets.
        ///
        /// Requirements:
        ///
        /// - `operator` cannot be the caller.
        ///
        /// Emits an `NFTApprovalForAll` event.
        fn set_approval_for_all(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            let caller = get_caller_address();

            assert(caller != operator, Errors::SELF_APPROVAL);

            self.ERC404_is_approved_for_all.write((caller, operator), approved);

            self.emit(NFTApprovalForAll { owner: caller, operator, approved });
        }

        /// Returns the address approved for `token_id`.
        ///
        /// Requirements:
        ///
        /// - `token_id` exists.
        fn get_approved(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            assert(!self.ERC404_owner_of.read(token_id).is_zero(), Errors::INVALID_TOKEN_ID);
            self.ERC404_get_approved.read(token_id)
        }

        /// Query if `operator` is an authorized operator for `owner`.
        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.ERC404_is_approved_for_all.read((owner, operator))
        }

        /// Get the token id at the index in the token id user owned array
        fn get_owned(
            self: @ComponentState<TContractState>, owner: ContractAddress, index: u32
        ) -> u256 {
            self.ERC404_owned.read(owner)[index]
        }

        /// Get the token id index in its owner's array
        fn get_owned_index(self: @ComponentState<TContractState>, token_id: u256) -> u32 {
            assert(!self.ERC404_owner_of.read(token_id).is_zero(), Errors::INVALID_TOKEN_ID);
            self.ERC404_owned_index.read(token_id)
        }

        /// Get current mint counter
        fn get_minted(self: @ComponentState<TContractState>) -> u256 {
            self.ERC404_minted.read()
        }

        /// Increases the allowance granted from the caller to `spender` by `added_value`
        fn increase_allowance(
            ref self: ComponentState<TContractState>, spender: ContractAddress, added_value: u256
        ) {
            let caller = get_caller_address();
            let cur_allowances = self.ERC404_allowances.read((caller, spender));
            self.ERC404_allowances.write((caller, spender), cur_allowances + added_value);
            self.emit(Approval { owner: caller, spender, value: cur_allowances + added_value });
        }

        /// Decreases the allowance granted from the caller to `spender` by `subtracted_value`
        fn decrease_allowance(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            subtracted_value: u256
        ) {
            let caller = get_caller_address();
            let cur_allowances = self.ERC404_allowances.read((caller, spender));
            assert(cur_allowances >= subtracted_value, Errors::EXCEEDS_CUR_ALLOWANCES);
            self.ERC404_allowances.write((caller, spender), cur_allowances - subtracted_value);
            self
                .emit(
                    Approval { owner: caller, spender, value: cur_allowances - subtracted_value }
                );
        }
    }

    #[embeddable_as(ERC404MetadataImpl)]
    impl ERC404Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC404Metadata<ComponentState<TContractState>> {
        /// Returns the name of the token.
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            self.ERC404_name.read()
        }

        /// Returns the ticker symbol of the token, usually a shorter version of the name.
        fn symbol(self: @ComponentState<TContractState>) -> felt252 {
            self.ERC404_symbol.read()
        }

        /// Returns the number of decimals used to get its user representation.
        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            self.ERC404_decimals.read()
        }

        // Return the fractionalized for 1 native amount
        fn units(self: @ComponentState<TContractState>) -> u256 {
            fast_power(
                10, self.ERC404_decimals.read().into(), 340282366920938463463374607431768211454
            )
                .into()
        }
    }

    #[embeddable_as(ERC404AdminImpl)]
    impl ERC404Admin<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC404Admin<ComponentState<TContractState>> {
        /// Initialization function to set pairs / etc
        /// saving gas by avoiding mint / burn on unnecessary targets
        fn set_whitelist(
            ref self: ComponentState<TContractState>, target: ContractAddress, state: bool
        ) {
            // Check owner
            let caller = get_caller_address();
            assert(caller == self.ERC404_owner.read(), Errors::NOT_OWNER);

            self.ERC404_whitelist.write(target, state);
        }

        fn is_whitelist(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            self.ERC404_whitelist.read(address)
        }

        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ERC404_owner.read()
        }
    }

    #[embeddable_as(ERC404CamelOnlyImpl)]
    impl ERC404CamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC404CamelOnly<ComponentState<TContractState>> {
        fn totalSupply(self: @ComponentState<TContractState>) -> u256 {
            self.total_supply()
        }

        fn erc20TotalSupply(self: @ComponentState<TContractState>) -> u256 {
            self.erc20_total_supply()
        }

        fn erc721TotalSupply(self: @ComponentState<TContractState>) -> u256 {
            self.erc721_total_supply()
        }

        fn balanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.balance_of(account)
        }

        fn erc20BalanceOf(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            self.erc20_balance_of(account)
        }

        fn erc721BalanceOf(
            self: @ComponentState<TContractState>, account: ContractAddress
        ) -> u256 {
            self.erc721_balance_of(account)
        }

        fn safeTransferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            id: u256,
            data: Span<felt252>
        ) {
            self.safe_transfer_from(from, to, id, data)
        }

        fn transferFrom(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amountOrId: u256
        ) -> bool {
            self.transfer_from(from, to, amountOrId)
        }

        fn ownerOf(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            self.owner_of(tokenId)
        }

        fn setApprovalForAll(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            self.set_approval_for_all(operator, approved)
        }

        fn getApproved(self: @ComponentState<TContractState>, tokenId: u256) -> ContractAddress {
            self.get_approved(tokenId)
        }

        fn isApprovedForAll(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.is_approved_for_all(owner, operator)
        }

        fn getOwned(
            self: @ComponentState<TContractState>, owner: ContractAddress, index: u32
        ) -> u256 {
            self.get_owned(owner, index)
        }

        fn getOwnedIndex(self: @ComponentState<TContractState>, tokenId: u256) -> u32 {
            self.get_owned_index(tokenId)
        }

        fn getMinted(self: @ComponentState<TContractState>) -> u256 {
            self.get_minted()
        }

        fn increaseAllowance(
            ref self: ComponentState<TContractState>, spender: ContractAddress, addedValue: u256
        ) {
            self.increase_allowance(spender, addedValue);
        }

        fn decreaseAllowance(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            subtractedValue: u256
        ) {
            self.decrease_allowance(spender, subtractedValue);
        }
    }

    #[embeddable_as(ERC404AdminCamelOnlyImpl)]
    impl ERC404AdminCamelOnly<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC404AdminCamelOnly<ComponentState<TContractState>> {
        /// Initialization function to set pairs / etc
        /// saving gas by avoiding mint / burn on unnecessary targets
        fn setWhitelist(
            ref self: ComponentState<TContractState>, target: ContractAddress, state: bool
        ) {
            self.set_whitelist(target, state)
        }

        fn isWhitelist(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            self.is_whitelist(address)
        }
    }

    //
    // Internal
    //

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of InternalTrait<TContractState> {
        /// Initializes the contract by setting the token name and symbol.
        /// To prevent reinitialization, this should only be used inside of a contract's constructor.
        fn initializer(
            ref self: ComponentState<TContractState>,
            name: felt252,
            symbol: felt252,
            decimals: u8,
            total_native_supply: u256,
            owner: ContractAddress
        ) {
            self.ERC404_name.write(name);
            self.ERC404_symbol.write(symbol);
            self.ERC404_decimals.write(decimals);
            self
                .ERC404_ERC20_total_supply
                .write(
                    total_native_supply
                        * fast_power(10, decimals.into(), 340282366920938463463374607431768211454)
                            .into()
                );
            self.ERC404_owner.write(owner);
            self.ERC404_ERC20_balances.write(owner, self.ERC404_ERC20_total_supply.read());

            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(interface::IERC404_ID);
            src5_component.register_interface(interface::IERC404_METADATA_ID);
            src5_component.register_interface(interface::IERC404_ADMIN_ID);
        }

        /// Internal method that moves an `amount` of tokens from `from` to `to`.
        ///
        /// Requirements:
        ///
        /// - `from` is not the zero address.
        /// - `from` must have at least a balance of `amount`.
        /// - `to` is not the zero address.
        ///
        /// Emits a `Transfer` event.
        fn _transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            amount: u256
        ) {
            assert(from.is_non_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(to.is_non_zero(), Errors::TRANSFER_TO_ZERO);

            let balanceBeforeSender = self.ERC404_ERC20_balances.read(from);
            let balanceBeforeReceiver = self.ERC404_ERC20_balances.read(to);

            assert(balanceBeforeSender >= amount, Errors::NOT_ENOUGH_ERC20_BALANCES);

            let uint: u256 = self.units();

            self.ERC404_ERC20_balances.write(from, self.ERC404_ERC20_balances.read(from) - amount);
            self.ERC404_ERC20_balances.write(to, self.ERC404_ERC20_balances.read(to) + amount);

            // Skip burning for certain addresses to save gas
            if (!self.ERC404_whitelist.read(from)) {
                let tokens_to_burn = (balanceBeforeSender / uint)
                    - (self.ERC404_ERC20_balances.read(from) / uint);

                let mut index: u256 = 0;
                loop {
                    if (index == tokens_to_burn) {
                        break ();
                    }

                    // Burn
                    self._burn(from);

                    // Increase index
                    index = index + 1;
                }
            }

            // Skip minting for certain addresses to save gas
            if (!self.ERC404_whitelist.read(to)) {
                let tokens_to_mint = (self.ERC404_ERC20_balances.read(to) / uint)
                    - (balanceBeforeReceiver / uint);

                let mut index: u256 = 0;
                loop {
                    if (index == tokens_to_mint) {
                        break ();
                    }

                    // Mint
                    self._mint(to);

                    // Increase index
                    index = index + 1;
                }
            }

            self.emit(Transfer { from, to, value: amount });
        }

        /// Mints NFT and transfers it to `to`.
        /// Internal function without access restriction.
        ///
        /// Requirements:
        ///
        /// - `to` is not the zero address.
        ///
        /// Emits a `NFTTransfer` event.
        fn _mint(ref self: ComponentState<TContractState>, to: ContractAddress) {
            assert(to.is_non_zero(), Errors::INVALID_RECEIVER);

            self.ERC404_minted.write(self.ERC404_minted.read() + 1);

            let id = self.ERC404_minted.read();

            assert(self.ERC404_owner_of.read(id) == Zeroable::zero(), Errors::ALREADY_MINTED);

            self.ERC404_owner_of.write(id, to);
            let mut curToIds = self.ERC404_owned.read(to);
            let _ = curToIds.append(id);
            self.ERC404_owned.write(to, curToIds);
            self.ERC404_owned_index.write(id, self.ERC404_owned.read(to).len() - 1);

            // Update total supply & balances
            self.ERC404_ERC721_total_supply.write(self.ERC404_ERC721_total_supply.read() + 1);
            self.ERC404_ERC721_balances.write(to, self.ERC404_ERC721_balances.read(to) + 1);

            self.emit(NFTTransfer { from: Zeroable::zero(), to, token_id: id });
        }

        /// Destroys NFT. The approval is cleared when the token is burned.
        ///
        /// This internal function does not check if the caller is authorized
        /// to operate on the token.
        ///
        /// Requirements:
        ///
        /// - `from` is not the zero address.
        ///
        /// Emits a `NFTTransfer` event.
        fn _burn(ref self: ComponentState<TContractState>, from: ContractAddress) {
            assert(from.is_non_zero(), Errors::INVALID_SENDER);

            let id = self.ERC404_owned.read(from)[self.ERC404_owned.read(from).len() - 1];
            let mut curFromIds = self.ERC404_owned.read(from);
            let _ = curFromIds.pop_front(); // Pop
            self.ERC404_owned.write(from, curFromIds);

            // Update total supply & balances
            self.ERC404_ERC721_total_supply.write(self.ERC404_ERC721_total_supply.read() - 1);
            self.ERC404_ERC721_balances.write(from, self.ERC404_ERC721_balances.read(from) - 1);

            // Delete
            self.ERC404_owned_index.write(id, 0);
            self.ERC404_owner_of.write(id, Zeroable::zero());
            self.ERC404_get_approved.write(id, Zeroable::zero());

            self.emit(NFTTransfer { from, to: Zeroable::zero(), token_id: id });
        }
    }

    /// Checks if `to` either is an account contract or has registered support
    /// for the `IERC721Receiver` interface through SRC5. The transaction will
    /// fail if both cases are false.
    fn _check_on_erc721_received(
        from: ContractAddress, to: ContractAddress, token_id: u256, data: Span<felt252>
    ) -> bool {
        if (DualCaseSRC5 { contract_address: to }
            .supports_interface(interface::IERC721_RECEIVER_ID)) {
            DualCaseERC721Receiver { contract_address: to }
                .on_erc721_received(
                    get_caller_address(), from, token_id, data
                ) == interface::IERC721_RECEIVER_ID
        } else {
            DualCaseSRC5 { contract_address: to }.supports_interface(account::interface::ISRC6_ID)
        }
    }
}
