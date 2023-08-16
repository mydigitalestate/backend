create table
  public.log (
    username character varying not null,
    last_access timestamp with time zone null default now(),
    constraint log_pkey primary key (username)
  ) tablespace pg_default;