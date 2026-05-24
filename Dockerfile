FROM alpine:3.18

# Install bash and git
RUN apk add --no-cache bash git

# Copy the script into the container
COPY entrypoint.sh /entrypoint.sh

# Make the script executable
RUN chmod +x /entrypoint.sh

# Set the script as the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
