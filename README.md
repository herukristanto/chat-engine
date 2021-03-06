# Kiwari Engine

Kiwari, The Indonesia's Instant Messaging App. This engine built with rails.

## Requirement

* Ruby 2.4.1
* Bundler 1.14.6
* Rais 5.1.1
* Latest Docker with `docker-compose`
* PostgreSQL 9.6
* Redis

## Environment Key

Environment Variable that used by Kiwari Engine.

Configuration, please make sure you have set this **ENVIRONMENT KEY**, for detailed key, please refer to [application.yml.sample](./config/application.yml.sample) file.

  * `JWT_KEY`
  * `CLOUDINARY_API_KEY`
  * `CLOUDINARY_API_SECRET`
  * `CLOUDINARY_CLOUD_NAME`
  * `NEXMO_API_KEY`
  * `NEXMO_API_SECRET`
  * `TWILIO_SID_KEY`
  * `TWILIO_TOKEN_KEY`
  * `EMAIL_SENDER`
  * `MAILGUN_API_KEY`
  * `MAILGUN_DOMAIN`
  * `SENTRY_DSN`
  * `PAPERTRAIL_API_TOKEN`
  * `NEW_RELIC_LICENSE_KEY`
  * `REDIS_URL`
  * `REDIS_CACHE`
  * `SUPER_ADMIN_USERNAME`
  * `SUPER_ADMIN_PASSWORD`
  * `IS_PUSHKIT_DEV`
  * `IS_APNS_DEV`
  * `SIDEKIQ_USERNAME`
  * `SIDEKIQ_PASSWORD`

* Database creation, you can either set via `DATABASE_URL` string or
  * `APP_DATABASE_HOST`
  * `APP_DATABASE_PORT`
  * `APP_DATABASE_USERNAME`
  * `APP_DATABASE_PASSWORD`
  * `APP_DATABASE_NAME`
  * `APP_DATABASE_TEST_NAME`

## How to Run

### Common

* Clone this repository
* Edit environment in `application.yml`

```bash
$ cd kiwari-engine
$ cp config/application.yml.sample config/application.yml
```
* After edit `application.yml`, you need to run

```bash
$ bundle install
$ rails db:migrate
$ rails db:seed
```

* Start server using `rails s`
* Open browser and go to `localhost:3000/superadmin`

### Using Docker

* Clone this repository
* Build docker image

```bash
$ cd kiwari-engine
$ docker build -t kiwari-engine .
```

* Run using `docker-compose`

```bash
$ cp docker-compose.yml.example docker-compose.yml
```

edit `docker-compose.yml` file to meet your configuration, then run :

```bash
$ docker-compose up
```

* Now your kiwari-engine is up at `localhost:8000`
* You can monitoring background processing using `web-ui` at `localhost:8000/sidekiq`

## Data Initialization

* Open your kiwari-engine via `docker exec`, init the migration and seed initialize the data

```bash
$ docker exec -it yourcontainer bash
$ rails db:migrate
$ rails db:seed
```

After that, you need to create your own application via rails console:

```ruby
params = {
  :app_id => 'kiwari-local',
  :app_name => 'Kiwari Local Application',
  :app_description => 'Kiwari local description',
  :qiscus_sdk_url => 'yourqiscussdkurl',
  :qiscus_sdk_secret => 'yourqiscussdksecret',
  :sms_server => 'VERIFY',
  :secret_key => '',
  :fcm_key => ''
}

Application.create(params)
```

Then if you want to register new user, you can post it via Postman or using CURL:

```bash
curl -X POST -H "Content-Type: multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW" -F "user[phone_number]=+6281233541554" -F "user[app_id]=kiwari-stag" "{URL}/api/v1/auth/"
```

If you want to set a registered user as an admin, you can do via dashboard admin page or via console:

```ruby
u = User.find_by(phone_number: "+6281233541554")
UserRole.create(user: u, role: Role.admin)
```

## Deployment

_todo_

## Building Documentation

There are 2 tools to build docs. First [MKDOCS](http://www.mkdocs.org/) to build static page via markdown file, second is [APIDOCJS](http://apidocjs.com/) to build Inline Documentation for RESTful web APIs.

Installing two of them is easy, but they need this prerequisites:

For MKDOCS, it needs:

* Python 2.7 or later
* PIP 1.5.2 or later

For APIDOCJS, needs:

* NodeJS v6 or later
* NPM v3 or later

Then install mkdocs and apidocjs:

```
$ sudo pip install mkdocs
$ sudo npm install --global apidoc
```

After installation completed, you can build new api doc using following command from rails root directory:

```
$ apidoc -i app/controllers -o docs/apidoc
```

Please keep in mind that you must generate apidoc in `docs/apidoc` directory.

If you change or add new file inside `docs/docs` directory (for instance you adding some note in there), you must re-generate your docs to html using mkdocs. First, change your directory to `docs`, then run `mkdocs build`, here is the full command:

```
$ cd docs
$ mkdocs build
$ cd ..
```

And now your documentation is up-to-date, don't forget to commit and push it into repo.

## Troubleshooting

_todo_