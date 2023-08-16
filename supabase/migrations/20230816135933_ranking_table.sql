create table
  public.ranking (
    name text not null,
    first_line_rate numeric not null,
    second_line_rate numeric not null,
    third_line_rate numeric not null,
    constraint ranking_pkey primary key (name)
  ) tablespace pg_default;