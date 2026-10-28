# Firebase email wording (sign-in emails)

Firebase sends the password-reset email today, and would send the "confirm your email" email if you choose that route (decision B1, Option A). Their default text is English boilerplate and often goes to Spam. This is the wording to paste in.

Where: Firebase console, project `rakta-bandhan-india`, **Authentication**, tab **Templates**. Click the pencil on each template. The words `%LINK%`, `%EMAIL%` and `%APP_NAME%` are filled in by Firebase. Keep them exactly.

## Password reset (in use now)

| Field | Value |
|---|---|
| Sender name | Rakta Bandhan |
| Reply to | leave empty until the support@ mailbox exists, then put it here |
| Subject | Reset your Rakta Bandhan password |

Message:

```
Hello,

Follow this link to reset your Rakta Bandhan password for %EMAIL%.

%LINK%

If you did not ask for this, ignore this email. Your password stays the same.

If this email was in your Spam folder, please mark it "Not spam" so you do not miss important messages.

Thank you,
The Rakta Bandhan team
```

## Email address verification (only if you choose Option A in B1)

| Field | Value |
|---|---|
| Sender name | Rakta Bandhan |
| Subject | Confirm your email for Rakta Bandhan |

Message:

```
Hello,

Please confirm that %EMAIL% is your email for Rakta Bandhan.

%LINK%

Then go back to the app and tap "I have confirmed".

If you did not create this account, ignore this email.

If this email was in your Spam folder, please mark it "Not spam".

Thank you,
The Rakta Bandhan team
```

## Later, once the domain exists

On the same Templates page, **Customize domain** replaces `noreply@rakta-bandhan-india.firebaseapp.com` with an address on your own domain (it gives you DNS records to add). Mail from your own domain reaches the inbox far more often than from a firebaseapp.com address.
