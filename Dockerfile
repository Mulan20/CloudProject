#using the official nginx image 
FROM nginx:alpine

#copying the content of the html directory to the nginx html directory 
COPY . /usr/share/nginx/html

#Expose port 80 to the outside world 
EXPOSE 80 
