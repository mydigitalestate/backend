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

create index if not exists transactions_source_idx on public.transactions using btree (source) tablespace pg_default;

create index if not exists transactions_destination_idx on public.transactions using btree (destination) tablespace pg_default;

create trigger update_total_investment_trigger
after insert
or
update of destination on transactions for each row
execute function update_total_investment ();

create trigger create_second_line_referral_transaction
after insert on transactions for each row
execute function create_second_line_referral_transaction ();

create trigger update_user_profits
after insert on transactions for each row
execute function update_user_profits ();

create trigger check_transaction_amount before insert on transactions for each row
execute function validate_transaction_amount ();

create trigger notify_andreafuturi
after insert on transactions for each row
execute function notify_andreafuturi ();

create trigger create_third_line_referral_transaction
after insert on transactions for each row
execute function create_third_line_referral_transaction ();

create trigger update_house_investors
after insert on transactions for each row
execute function update_house_investors ();

create trigger deposit_notification_trigger
after insert on transactions for each row when (
  length(new.source::text) > 20
  and length(new.destination::text) < 20
)
execute function deposit_notification ();

create trigger create_referral_notification
after insert on transactions for each row
execute function create_referral_notification ();

create trigger update_amount_reached
after insert on transactions for each row
execute function update_amount_reached ();

create trigger create_referral_transaction
after insert on transactions for each row
execute function create_referral_transaction ();

create trigger increase_user_balance
after insert on transactions for each row
execute function increase_user_balance ();

create trigger decrease_user_balance
after insert on transactions for each row
execute function decrease_user_balance ();