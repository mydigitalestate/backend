create table
  public.transactions (
    id serial,
    source character varying(255) not null default get_username (auth.uid ()),
    destination character varying(255) not null,
    amount numeric(10, 2) not null,
    timestamp timestamp with time zone null default now(),
    status text null default 'completed'::text,
    constraint transactions_pkey primary key (id),
    constraint amount_check check ((amount > (0)::numeric))
  ) tablespace pg_default;