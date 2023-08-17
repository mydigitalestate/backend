create table
  public.referrals (
    username text not null,
    invited_by text null,
    subscribed_at timestamp with time zone not null default now(),
    constraint referrals_pkey primary key (username)
  ) tablespace pg_default;

create trigger increment_first_line_trigger
after insert on referrals for each row
execute function increment_first_line ();

create trigger increment_second_line_trigger
after insert on referrals for each row
execute function increment_second_line ();

create trigger increment_third_line_trigger
after insert on referrals for each row
execute function increment_third_line ();

create trigger limit_inviter_trigger before insert on referrals for each row
execute function limit_inviter ();