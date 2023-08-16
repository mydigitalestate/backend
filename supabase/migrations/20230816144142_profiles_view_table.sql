create view
  public.profiles_view as
select
  profiles.username,
  profiles.email,
  profiles.ranking,
  profiles.display_name,
  profiles.public_profile
from
  profiles;