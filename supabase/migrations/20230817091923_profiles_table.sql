create table
  public.profiles (
    username text not null,
    display_name text null,
    balance numeric not null default '5000'::numeric,
    ranking text not null default 'Citizen'::text,
    public_profile boolean not null default true,
    total_investments real not null default '0'::real,
    total_profits real not null default '0'::real,
    first_line integer not null default 0,
    second_line integer not null default 0,
    third_line integer not null default 0,
    invited_by text null,
    email text not null default ''::text,
    id uuid null,
    invite_limits numeric null default '0'::numeric,
    constraint users_pkey primary key (username),
    constraint profiles_id_key unique (id),
    constraint profiles_email_key unique (email),
    constraint profiles_invited_by_fkey foreign key (invited_by) references profiles (username),
    constraint profiles_id_fkey foreign key (id) references auth.users (id),
    constraint profiles_ranking_fkey foreign key (ranking) references ranking (name),
    constraint username_blacklist_constraint check (
      (
        username <> all (
          array[
            ('settings'::character varying)::text,
            ('dashboard'::character varying)::text,
            ('login'::character varying)::text,
            ('register'::character varying)::text,
            ('recap'::character varying)::text,
            ('investments'::character varying)::text,
            ('profits'::character varying)::text,
            ('network'::character varying)::text,
            ('feed'::character varying)::text,
            ('market'::character varying)::text,
            ('balance'::character varying)::text,
            ('addwallet'::character varying)::text
          ]
        )
      )
    ),
    constraint username_constraint check ((length(username) < 20)),
    constraint check_balance check ((balance >= (0)::numeric))
  ) tablespace pg_default;

create index if not exists idx_profiles_id on public.profiles using btree (id) tablespace pg_default;

create index if not exists idx_invited_by on public.profiles using btree (invited_by) tablespace pg_default;

create index if not exists users_name_idx on public.profiles using btree (username) tablespace pg_default;

create trigger create_new_citizen_notification
after insert on profiles for each row
execute function create_new_citizen_notification ();

create trigger delete_referral
after delete on profiles for each row
execute function delete_referral_func ();

create trigger notify_rank_change
after
update on profiles for each row
execute function notify_rank_change ();

create trigger notify_rank_change_network
after
update on profiles for each row
execute function notify_rank_change_network ();

create trigger insert_referral
after insert on profiles for each row
execute function insert_referral_func ();