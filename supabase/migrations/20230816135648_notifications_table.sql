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

create trigger sendpushnotifications
after insert on notifications for each row
execute function supabase_functions.http_request (
  'https://rcyfuqhvepjazgqupycs.functions.supabase.co/notify',
  'POST',
  '{"Content-type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJjeWZ1cWh2ZXBqYXpncXVweWNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE2NzQzMDMwNDUsImV4cCI6MTk4OTg3OTA0NX0.dsF72KtkI2NGazBZcBWq6MwP80gkYcUCu_K-MLGd9lA"}',
  '{}',
  '1000'
);