FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/credit-risk-system-0.0.1-SNAPSHOT.jar app.jar
ENV JAVA_OPTS=""
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
