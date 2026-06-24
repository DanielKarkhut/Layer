The main Idea of Layer:

This is an iPhone App

The purpose of this is for Artists to drop Songs at Locations that Users can Download if they are within a certain Radius around the Location




MVP

User can See:

- map showing songs at locations
- library with the songs theyve found (swift db)

User can Do:

- Decide to download the songs they find
- Listen to the songs they find
- Upload their own song

=============================

STEP 1:

=============================

Backend:

Database (supabase / postgres)

- Song information
- song name (string)
- s3 link (string)
- user who uploaded name (string)
- x coord (long)
- y coord (long)
- radius (int)
- upload timestamp (Time object)
- experation timestamp (Time object)
- misc (String)
- uuid (uuid)
- foreign key ( UUID ( user ) )
- User information
- username (String)
- password (String)
- uuid ( UUID )

S3 bucket for blob storage

=============================

Once thats setup .... script to pull a song from the DB and write onto the app's map!

=======================
