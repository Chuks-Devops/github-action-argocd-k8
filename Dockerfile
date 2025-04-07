# Step 1: Use an official Node.js image as the base image
FROM node:16-alpine

# Step 2: Set the working directory inside the container
WORKDIR /app

# Step 3: Copy the package.json and package-lock.json files into the container
COPY package*.json ./

# Step 4: Install the dependencies inside the container
RUN npm install

# Step 5: Copy the rest of the application into the container
COPY . .

# Step 6: Build the React app for production
RUN npm run build

# Step 7: Install a lightweight web server to serve the build files
RUN npm install -g serve

# Step 8: Expose port 5000 (or any other port you want to use)
EXPOSE 5000

# Step 9: Run the app using 'serve' to serve the production build
CMD ["serve", "-s", "build", "-l", "5000"]
