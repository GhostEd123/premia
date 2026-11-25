#   
##   
Base URL: https://premia-frontend-prev.onrender.com  

**1. Auth (Mobile-friendly)**  
* GET /api/auth/verify?token=<magicLinkToken> now returns accessToken in the JSON body. Pass Authorization: Bearer <accessToken> on all host/lobby/playback calls.  

**2. Host Invites & Manages Guests *(Works even BEFORE premiereStart)***  
* **POST /api/parties/invites** *(Host Bearer token)* 
   {   "ticketId": "<claimedTicketId>",   "guests": [     { "name": "Tunde", "email": "tunde@example.com" },     { "name": "Ada", "email": "ada@example.com" }   ] }       
    * Returns { partyId, filmId, status: "waiting", isHost: true, hostOnline, maxGuests, remainingSlots, guests: [{ name, email, status: "sent", invitedAt, joinedAt }], socketToken }.  

* **DELETE /api/parties/:partyId/invites** *(Host Bearer token)* — Body { "email": "ada@example.com" } removes an invited guest (e.g., typo fix) and frees the slot.  

* **POST /api/parties/:partyId/invites/resend** *(Host Bearer token)* — Body { "email": "tunde@example.com" } resends their invite link.  

**3. Guest Enters the Wait Lobby *(Works BEFORE premiereStart and before the Host arrives)***  
* **POST /api/parties/join-lobby**    { "inviteToken": "<token_from_invite_link>" }      
    * Flips that guest's status from **sent → in_lobby**, broadcasts lobbyUpdated to the room, and returns { partyId, status, guestName, hostOnline, guests, accessToken, socketToken, film }.  

**4. Fetch Current Lobby State *(Host or Guest)***  
* **GET /api/parties/lobby?ticketId=<id>** *(or ?partyId=<id>, Bearer token)* — Returns current status (not_created | waiting | active), hostOnline, full guests list (name, email, status), and a fresh socketToken.  

**5. Real-Time Socket.IO Lobby Events**  
Connect with { auth: { token: socketToken } } and emit joinParty ({ partyId }):  
* **lobbyUpdated** *(Server → Room)* — Fires whenever a guest is invited, removed, joins the lobby, or host presence changes. Payload: { partyId, status, hostOnline, maxGuests, remainingSlots, guests }.  
* **partyStarted** *(Server → Room)* — Fires when the host taps Start Screening (POST /api/playback/authorize). Payload: { partyId, filmId, elapsedTime }. Guests' apps can listen for this and automatically call POST /api/playback/authorize with { deviceId, inviteToken } to enter the video player.  


* *(If a guest calls POST /api/playback/authorize before the host starts, the server returns 409 with { partyStatus: "waiting", partyId } instead of an error claiming the party ended.)*  
