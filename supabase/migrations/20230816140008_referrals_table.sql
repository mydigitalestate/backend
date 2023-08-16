create table
  public.referrals (
    username text not null,
    invited_by text null,
    subscribed_at timestamp with time zone not null default now(),
    constraint referrals_pkey primary key (username)
  ) tablespace pg_default;