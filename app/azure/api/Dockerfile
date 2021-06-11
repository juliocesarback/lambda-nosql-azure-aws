FROM python:3

WORKDIR /usr/src/app

#COPY requirements.txt ./
#RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir azure-cosmos

COPY . .

CMD [ "python", "./cosmos_get_started.py" ]