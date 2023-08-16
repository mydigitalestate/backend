create table
  public.notifications (
    id serial,
    usernames text[] null,
    title text not null,
    message text not null,
    date timestamp with time zone not null default now(),
    image text null,
    read text[] null,
    value numeric(10, 2) null,
    link text null,
    icon text null,
    color text null,
    platform text[] null,
    constraint notifications_pkey primary key (id)
  ) tablespace pg_default;