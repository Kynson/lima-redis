# v2.0.1 (20-07-2022)
**Fix:**
- Update [test.sh](scripts/test.sh), use the correct secret name.

# v2.0.0 (20-07-2022)
**Breaking Changes:**  
  
The built image no longer contains the required secrets. Both `redis-init-secrets.txt` and `redis-users.acl` must be supplied as secret when the container is started. `redis-users.acl` must be supplied as secret during build.
- Update [ci.yml](.github/workflows/ci.yml), CI no longer use `build.sh` to include secrets in the image.
- Update [Containerfile](Containerfile), a symbolic link of `/run/secrets/redis-users.acl` will be created during build, instead of including the actual ACL file.
- Update [redis-init.sh](redis-init.sh), init script now loads the provided secrets from `/run/secrets/redis-init-secrets.txt`.
- Update [test.sh](scripts/test.sh) to due to above changes. 

**Other Changes:**
- Update [redis-init.sh](redis-init.sh) and [redis.conf](redis.conf) to improve logging.

# v1.0.1 (23-04-2022)
**Fix:**
- Update [build.sh](scripts/build.sh), use a semicolon as separator instead of a slash in ed. This allows secret variables with slash to be replaced correctly.

# v1.0.0 (23-04-2022)
This is the initial release