#[starknet::contract]
mod MyERC404 {
    use erc404::token::erc404::interface::IERC404;
    use alexandria_ascii::ToAsciiTrait;
    use core::Zeroable;
    use erc404::token::erc404::ERC404Component;
    use openzeppelin::introspection::dual_src5::{DualCaseSRC5, DualCaseSRC5Trait};
    use openzeppelin::introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use starknet::get_contract_address;

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
        #[substorage(v0)]
        erc404: ERC404Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        total_uris: u256
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC404Event: ERC404Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    mod Errors {
        const INVALID_TOKEN_ID: felt252 = 'ERC404: invalid token ID';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, total_native_supply: u256, total_uris: u256, owner: ContractAddress
    ) {
        let name = 'Summer NFT Collection';
        let symbol = 'SNC';
        let decimals = 18;

        self.erc404.initializer(name, symbol, decimals, total_native_supply, owner);
        self.total_uris.write(total_uris);
    }

    #[external(v0)]
    fn token_uri(self: @ContractState, token_id: u256) -> Span<felt252> {
        // Example for repeated token_id
        let mut handled_token_id = token_id % self.total_uris.read();
        if (handled_token_id == 0) {
            handled_token_id = self.total_uris.read();
        }

        assert(self.erc404.ERC404_owner_of.read(token_id).is_non_zero(), Errors::INVALID_TOKEN_ID);
        let mut a = ArrayTrait::new();
        let token_id_str: felt252 = handled_token_id.low.to_ascii();
        a.append('https://grow-api.memeland.com/');
        a.append('token/');
        a.append('metadata/');
        a.append(token_id_str);
        a.append('.json');
        a.span()
    }

    #[external(v0)]
    fn tokenURI(self: @ContractState, tokenId: u256) -> Span<felt252> {
        token_uri(self, tokenId)
    }
}
