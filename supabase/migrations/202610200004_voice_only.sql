do $$ begin
  if to_regclass('public.chat_calls') is not null then
    alter table public.chat_calls drop constraint if exists chat_calls_call_type_check;
    alter table public.chat_calls add constraint chat_calls_call_type_check check (call_type = 'voice');
  end if;
end $$;
