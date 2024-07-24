#[starknet::contract]
mod MyERC404 {
    use erc404::token::erc404::interface::IERC404Admin;
    use core::hash::HashStateTrait;
    use core::hash::HashStateExTrait;
    use erc404::token::erc404::interface::IERC404;
    use alexandria_ascii::ToAsciiTrait;
    use core::poseidon::PoseidonTrait;
    use core::Zeroable;
    use erc404::token::erc404::ERC404Component;
    use erc404::factory::ERC404Factory::DeployCallData;
    use openzeppelin::introspection::dual_src5::{DualCaseSRC5, DualCaseSRC5Trait};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::{ContractAddress, SyscallResultTrait};
    use starknet::{get_caller_address, get_contract_address};
    use starknet::class_hash::ClassHash;

    component!(path: ERC404Component, storage: erc404, event: ERC404Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC404
    #[abi(embed_v0)]
    impl ERC404Impl = ERC404Component::ERC404Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC404MetadataImpl = ERC404Component::ERC404MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC404AdminImpl = ERC404Component::ERC404AdminImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC404CamelOnlyImpl = ERC404Component::ERC404CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC404AdminCamelOnlyImpl =
        ERC404Component::ERC404AdminCamelOnlyImpl<ContractState>;
    impl ERC404InternalImpl = ERC404Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        protocol_owner: ContractAddress,
        #[substorage(v0)]
        erc404: ERC404Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        total_uris: u256,
        base_uri_1: felt252,
        base_uri_2: felt252,
        base_uri_3: felt252,
        base_uri_4: felt252,
        base_uri_5: felt252
    }

    #[derive(Drop, starknet::Event)]
    struct EventUpgraded {
        class_hash: ClassHash
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC404Event: ERC404Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        EventUpgraded: EventUpgraded
    }

    mod Errors {
        const NOT_FACTORY: felt252 = 'ERC404: not factory';
        const NOT_PROTOCOL_OWNER: felt252 = 'ERC404: not protocol owner';
        const INVALID_TOKEN_ID: felt252 = 'ERC404: invalid token ID';
        const INVALID_CLASS_HASH: felt252 = 'ERC404: invalid class hash';
    }

    #[constructor]
    fn constructor(ref self: ContractState, _deploy_data: DeployCallData) {
        let factory_address: ContractAddress =
            0x036130bc864f7f8df46abb04351b1b756581864e763b50879f6b66f569c34e7d
            .try_into()
            .unwrap();
        assert(get_caller_address() == factory_address, Errors::NOT_FACTORY);
        self.protocol_owner.write(_deploy_data._protocol_owner.try_into().unwrap());
        let total_native_supply_u256: u256 = _deploy_data._total_native_supply.into();
        let total_uris_u256: u256 = _deploy_data._total_uris.into();
        let owner_contract_address: ContractAddress = _deploy_data._owner.try_into().unwrap();
        let decimals_u8: u8 = _deploy_data._decimals.try_into().unwrap();

        self
            .erc404
            .initializer(
                _deploy_data._name,
                _deploy_data._symbol,
                decimals_u8,
                total_native_supply_u256,
                owner_contract_address
            );
        self.total_uris.write(total_uris_u256);
        self.base_uri_1.write(_deploy_data._base_uri_1);
        self.base_uri_2.write(_deploy_data._base_uri_2);
        self.base_uri_3.write(_deploy_data._base_uri_3);
        self.base_uri_4.write(_deploy_data._base_uri_4);
        self.base_uri_5.write(_deploy_data._base_uri_5);

        // Set whitelist for owner
        self.erc404.ERC404_whitelist.write(owner_contract_address, true);
    }

    #[external(v0)]
    fn token_uri(self: @ContractState, token_id: u256) -> Span<felt252> {
        assert(self.erc404.ERC404_owner_of.read(token_id).is_non_zero(), Errors::INVALID_TOKEN_ID);

        // Example for token_id get from rarity
        // let mut handled_token_id = rarity(self, token_id);

        // Example for repeated token_id
        let mut handled_token_id = token_id % self.total_uris.read();
        if (handled_token_id == 0) {
            handled_token_id = self.total_uris.read();
        }

        let mut a = ArrayTrait::new();
        let token_id_str: felt252 = handled_token_id.low.to_ascii();
        a.append(self.base_uri_1.read());
        a.append(self.base_uri_2.read());
        a.append(self.base_uri_3.read());
        a.append(self.base_uri_4.read());
        a.append(self.base_uri_5.read());
        a.append(token_id_str);
        a.append('.json');
        a.span()
    }

    #[external(v0)]
    fn tokenURI(self: @ContractState, tokenId: u256) -> Span<felt252> {
        token_uri(self, tokenId)
    }

    #[external(v0)]
    fn rarity(self: @ContractState, token_id: u256) -> u8 {
        let hash = PoseidonTrait::new().update_with(token_id).finalize();
        let seed256: u256 = hash.into();
        let seed: u8 = (seed256 % 256).try_into().unwrap();
        let mut rarity = 0;
        if (seed <= 100) {
            rarity = 1; // Rarity 1: 101/256 ~ 39.5%
        } else if (seed <= 160) {
            rarity = 2; // Rarity 2: 60/256 ~ 23.4%
        } else if (seed <= 210) {
            rarity = 3; // Rarity 3: 50/256 ~ 19.5%
        } else if (seed <= 240) {
            rarity = 4; // Rarity 4: 30/256 ~ 11.7%
        } else if (seed <= 255) {
            rarity = 5 // Rarity 5: 15/256 ~ 5.9%
        }
        rarity
    }

    #[external(v0)]
    fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
        /// Check owner
        let caller = get_caller_address();
        assert(caller == self.protocol_owner.read(), Errors::NOT_PROTOCOL_OWNER);

        /// Check class hash
        assert(!new_class_hash.is_zero(), Errors::INVALID_CLASS_HASH);

        /// Upgrade
        starknet::replace_class_syscall(new_class_hash).unwrap_syscall();
        self.emit(EventUpgraded { class_hash: new_class_hash });
    }
}
