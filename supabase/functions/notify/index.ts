import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
serve(async (req) => {
  const payload = await req.json()
  try {
    const url = 'https://progressier.app/VEWl7tUZUPlectHcM3V4/send'
    const data = {
      actions: [],
      campaigns: ['In-App Notificiations'],
      recipients: payload.record.usernames ? { id: payload.record.usernames.join(',') } : {},
      badge: null,
      icon: 'https://firebasestorage.googleapis.com/v0/b/pwaa-8d87e.appspot.com/o/azeKNaOQeQhrvNS5q1pd%2FEGAbFFbFHxKUEEb.png?alt=media&token=0fa1046e-08d8-4657-9a52-fc18adacdc3c',
      url: 'https://mydigitalestate.app/notifications',
      title: payload.record.title,
      body: payload.record.message,
    }
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        authorization: 'Bearer 56badmgnlr4xelwgafdfrp2aipnnh6lkar0cudf6pj8obod7',
        'content-type': 'application/json',
      },
      body: JSON.stringify(data),
    })
    const responseBody = await response.text()
    return new Response(JSON.stringify({ responseBody }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('Failed to create notification', err)
    return new Response('Server error.', {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
