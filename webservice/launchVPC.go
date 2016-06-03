package main

import (
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/ec2"
	"log"
)


func main(){

	ec := ec2.New(session.New(&aws.Config{Region: aws.String("us-east-1")}))
	//svc := s3.New(session.New(&aws.Config{Region: aws.String("us-west-2")}))


	res, err :=	ec.DescribeInstances(&ec2.DescribeInstancesInput{})

	if err==nil{

		for  _,ins :=range res.Reservations{

			//log.Println("here")
			for _, instance:=range ins.Instances{

				log.Println(*instance.InstanceId,*instance.InstanceType)
			}
		}

	}else{
		log.Print("crapp!!")
	}



	//
	//result, err := svc.ListBuckets(&s3.ListBucketsInput{})
	//if err != nil {
	//	log.Println("Failed to list buckets", err)
	//	return
	//}
	//
	//log.Println("Buckets:")
	//for _, bucket := range result.Buckets {
	//	log.Printf("%s : %s\n", aws.StringValue(bucket.Name), bucket.CreationDate)
	//
	//
	//}
}