create table
  public.wallets (
    address text not null,
    wallet_name text not null,
    owned_by text not null,
    is_verified boolean not null default false,
    blockchain text not null,
    constraint wallets_pkey primary key (address),
    constraint wallets_owned_by_fkey foreign key (owned_by) references profiles (username),
    constraint wallet_constraint check ((length(address) > 20))
  ) tablespace pg_default;
