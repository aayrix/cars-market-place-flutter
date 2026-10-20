-- Let each participant remove a direct conversation from their own inbox.
-- Messages remain available to the other participant and reappear after a
-- new message is sent in the thread.
alter table public.chat_threads
  add column if not exists buyer_hidden_at timestamptz,
  add column if not exists seller_hidden_at timestamptz;

-- Keep thread updates limited to previews and per-participant inbox state.
revoke update on public.chat_threads from authenticated;
grant update (last_message, last_message_at, buyer_hidden_at, seller_hidden_at)
  on public.chat_threads to authenticated;
